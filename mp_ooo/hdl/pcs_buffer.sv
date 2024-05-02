module pcs_buffer
import rv32i_types::*;
#(
    parameter DEPTH = 16
)
(
    input logic clk, rst,
    input super_dispatch_t store_queue_out,
    input logic push_pcs,
    input logic [31:0] pcs_addr,
    output pcs_t pcs_entry,
    input logic check_pcs_addr,
    input logic [3:0] pcs_rmask,
    input ld_st_controller_t lsq_state,

    output logic pcs_hit,
    output logic [255:0] pcs_cacheline,
    output logic write_pcs_cacheline,
    output logic [31:0] pcs_cacheline_mask,
    output logic [31:0] pcs_addr_req,
    input logic dmem_resp,
    output logic clear_pcs
);

super_dispatch_t pcs_table [DEPTH];
logic [31:0] pcs_addr_req_internal;
logic [31:0] first_occupied;
logic write_pcs_cacheline_comb;
logic [255:0] pcs_cacheline_comb, pcs_cacheline_full;
logic [31:0] pcs_cacheline_mask_comb, pcs_cacheline_mask_full;

assign pcs_addr_req_internal = pcs_table[first_occupied].cross_entry.pcs.rs1_data + pcs_table[first_occupied].cross_entry.pcs.immediate;

logic dmem_resp_reg;
always_ff @(posedge clk) begin
    if(rst)
        dmem_resp_reg <= 1'b0;
    else
        dmem_resp_reg <= dmem_resp;
end

// Determine hits
always_comb begin
    pcs_hit = 1'b0;
    write_pcs_cacheline_comb = 1'b0;
    if(check_pcs_addr) begin
        for(int i = 0; i < DEPTH; i++) begin
            if(pcs_table[i].cross_entry.valid && pcs_rmask == pcs_table[i].cross_entry.pcs.wmask &&
            pcs_addr[31:2] == {pcs_table[i].cross_entry.pcs.rs1_data + pcs_table[i].cross_entry.pcs.immediate}[31:2]) begin
                pcs_hit |= 1'b1;
            end

            // Comb
            if(pcs_table[i].cross_entry.valid &&
            pcs_addr[31:5] == {pcs_table[i].cross_entry.pcs.rs1_data + pcs_table[i].cross_entry.pcs.immediate}[31:5]) begin
                write_pcs_cacheline_comb |= 1'b1;
            end
        end
    end
end

// Determine cacheline to writeback so that load gets correct data
always_comb begin
    first_occupied = '0;
    // First occupied
    for(int i = 0; i < DEPTH; i++) begin
        if(pcs_table[i].cross_entry.valid) begin
            first_occupied = i;
            break;
        end
    end

    pcs_cacheline_comb = 256'b0;
    pcs_cacheline_mask_comb = 32'b0;
    pcs_cacheline_full = 256'b0;
    pcs_cacheline_mask_full = 32'b0;
    for(int i = 0; i < DEPTH; i++) begin
        // Comb
        if(pcs_table[i].cross_entry.valid &&
            pcs_addr[31:5] == {pcs_table[i].cross_entry.pcs.rs1_data + pcs_table[i].cross_entry.pcs.immediate}[31:5]) begin
            pcs_cacheline_mask_comb |= {32'(pcs_table[i].cross_entry.pcs.wmask) << {{pcs_table[i].cross_entry.pcs.rs1_data + pcs_table[i].cross_entry.pcs.immediate}[4:2], 2'b0}};
            pcs_cacheline_comb |= {256'(pcs_table[i].cross_entry.pcs.rs2_data) <<  8*{{pcs_table[i].cross_entry.pcs.rs1_data + pcs_table[i].cross_entry.pcs.immediate}[4:2], 2'b0}};
        end

        // Full
        if(pcs_table[i].cross_entry.valid &&
            {pcs_table[first_occupied].cross_entry.pcs.rs1_data + pcs_table[first_occupied].cross_entry.pcs.immediate}[31:5] 
            == {pcs_table[i].cross_entry.pcs.rs1_data + pcs_table[i].cross_entry.pcs.immediate}[31:5]) begin
            pcs_cacheline_mask_full |= {32'(pcs_table[i].cross_entry.pcs.wmask) << {{pcs_table[i].cross_entry.pcs.rs1_data + pcs_table[i].cross_entry.pcs.immediate}[4:2], 2'b0}};
            pcs_cacheline_full |= {256'(pcs_table[i].cross_entry.pcs.rs2_data) <<  8*{{pcs_table[i].cross_entry.pcs.rs1_data + pcs_table[i].cross_entry.pcs.immediate}[4:2], 2'b0}};
        end
    end
end

logic full, empty;
// Determine full and empty
always_comb begin
    full = 1'b1;
    empty = 1'b1;
    for(int i = 0; i < DEPTH; i++) begin
        full &= pcs_table[i].cross_entry.valid;
        empty &= ~pcs_table[i].cross_entry.valid;
    end
end

logic clear_pcs_internal;

always_ff @(posedge clk) begin
    if(rst)
        clear_pcs_internal <= 1'b0;
    else if(full)
        clear_pcs_internal <= 1'b1;
    else if(empty)
        clear_pcs_internal <= 1'b0;
end

always_comb begin
    if(full)
        clear_pcs = full;
    else
        clear_pcs = clear_pcs_internal;
end

// Register the values to prevent long critical path to cache
always_ff @(posedge clk) begin
    if(rst) begin
        write_pcs_cacheline <= 1'b0;
        pcs_cacheline <= 256'b0;
        pcs_cacheline_mask <= 32'b0;
    end
    else if(lsq_state == check_pcs_s) begin
        write_pcs_cacheline <= write_pcs_cacheline_comb;
        pcs_cacheline <= pcs_cacheline_comb;
        pcs_cacheline_mask <= pcs_cacheline_mask_comb;
    end
    else if(lsq_state == request_store_s && ~dmem_resp) begin
        pcs_addr_req <= pcs_addr_req_internal;
        write_pcs_cacheline <= 1'b0;
        pcs_cacheline <= pcs_cacheline_full;
        pcs_cacheline_mask <= pcs_cacheline_mask_full;
    end
    else if(dmem_resp || lsq_state == wait_s) begin
        write_pcs_cacheline <= 1'b0;
        pcs_cacheline <= 256'b0;
        pcs_cacheline_mask <= 32'b0;
    end
end

// Determine if we need to merge with an existing entry first
logic entry_exists;
always_comb begin
    entry_exists = 1'b0;
    for(int i = 0; i < DEPTH; i++) begin
        if(pcs_table[i].cross_entry.valid && {pcs_table[i].cross_entry.pcs.rs1_data + pcs_table[i].cross_entry.pcs.immediate}[31:2]
        == {store_queue_out.cross_entry.pcs.rs1_data + store_queue_out.cross_entry.pcs.immediate}[31:2]) begin
            entry_exists |= 1'b1;
        end
    end
end

// Add and vacate entries to the table as needed
always_ff @(posedge clk) begin
    if(rst) begin
        for(int i = 0; i < DEPTH; i++) begin
            pcs_table[i] <= '0;
        end
    end
    else begin
        if(push_pcs && ~entry_exists) begin
            for(int i = 0; i < DEPTH; i++) begin
                if(~pcs_table[i].cross_entry.valid) begin
                    pcs_table[i] <= store_queue_out;
                    break;
                end
            end
        end
        else if(push_pcs && entry_exists) begin
            for(int i = 0; i < DEPTH; i++) begin
                if(pcs_table[i].cross_entry.valid && {pcs_table[i].cross_entry.pcs.rs1_data + pcs_table[i].cross_entry.pcs.immediate}[31:2]
                == {store_queue_out.cross_entry.pcs.rs1_data + store_queue_out.cross_entry.pcs.immediate}[31:2]) begin
                    for(int j = 0; j < 4; j++) begin
                        if(store_queue_out.cross_entry.pcs.wmask[j])
                            pcs_table[i].cross_entry.pcs.rs2_data[8*j+:8] <= store_queue_out.cross_entry.pcs.rs2_data[8*j+:8];
                    end
                    pcs_table[i].cross_entry.pcs.wmask |= store_queue_out.cross_entry.pcs.wmask; 
                    break;
                end
            end
        end

        if(check_pcs_addr) begin
            for(int i = 0; i < DEPTH; i++) begin
                if(pcs_table[i].cross_entry.valid && pcs_rmask == pcs_table[i].cross_entry.pcs.wmask &&
                pcs_addr[31:2] == {pcs_table[i].cross_entry.pcs.rs1_data + pcs_table[i].cross_entry.pcs.immediate}[31:2]) begin
                    pcs_entry <= pcs_table[i].cross_entry.pcs;
                    break;
                end
            end
        end

        if(dmem_resp) begin
            for(int i = 0; i < DEPTH; i++) begin
                if(pcs_table[i].cross_entry.valid && ~clear_pcs &&
                pcs_addr[31:5] == {pcs_table[i].cross_entry.pcs.rs1_data + pcs_table[i].cross_entry.pcs.immediate}[31:5]) begin
                    pcs_table[i] <= '0;
                end

                if(pcs_table[i].cross_entry.valid && clear_pcs &&
                {pcs_table[first_occupied].cross_entry.pcs.rs1_data + pcs_table[first_occupied].cross_entry.pcs.immediate}[31:5] 
                == {pcs_table[i].cross_entry.pcs.rs1_data + pcs_table[i].cross_entry.pcs.immediate}[31:5]) begin
                    pcs_table[i] <= '0;
                end
            end
        end
    end
end

endmodule : pcs_buffer