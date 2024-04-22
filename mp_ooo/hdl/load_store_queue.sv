module load_store_queue
import rv32i_types::*;
#(
    parameter SS = 2,
    parameter LD_ST_DEPTH = 8
)
(
    input clk, rst,
    input logic avail_inst,
    input logic flush,
    input super_dispatch_t dispatch_entry [SS],

    // dmem interface signals
    output logic   [31:0]  dmem_addr,
    output logic           dmem_rmask,
    output logic   [3:0]   dmem_wmask,
    input logic   [31:0]  dmem_rdata,
    output logic   [31:0]  dmem_wdata,
    input logic          dmem_resp,

    // Regfile io
    output physical_reg_request_t lsq_request,
    input physical_reg_response_t lsq_reg_data,

    // Output to cdb
    output fu_output_t cdb_out,
    
    // Read off cdb
    input cdb_t cdb_in,

    // Rob comm on when to commit a store
    input logic commit_store

);

logic push_load, push_store, pop_load_ready, pop_store_ready, pop_load, pop_store;
logic [$clog2(LD_ST_DEPTH)-1:0] load_tail, store_tail, load_head, store_head;
logic load_full, store_full;
logic block_cdb;

// Hardcoded reg select
logic [$clog2(LD_ST_DEPTH)-1:0] reg_select_queue [LD_ST_DEPTH];
always_comb begin
    for(int unsigned i = 0; i < LD_ST_DEPTH; i++) begin
        reg_select_queue[i] = ($clog2(LD_ST_DEPTH))'(i);
    end
end

// Input into queues
super_dispatch_t load_queue_in [SS], load_queue_out [SS], store_queue_in [SS] , store_queue_out [SS];

// Entries of the queue to fw
logic [LD_ST_DEPTH-1:0] load_in_bit, store_in_bit;
super_dispatch_t load_in [LD_ST_DEPTH], load_out [LD_ST_DEPTH];
super_dispatch_t store_in [LD_ST_DEPTH], store_out [LD_ST_DEPTH];

// For now only properly support non-superscalar
assign push_load = avail_inst && ~load_full && dispatch_entry[0].inst.rmask != 4'b0;
assign push_store = avail_inst && ~store_full && dispatch_entry[0].inst.wmask != 4'b0;
assign pop_load_ready = load_out[load_tail].cross_entry.cross_dep_met && load_out[load_tail].rs_entry.input1_met
                    && load_out[load_tail].rs_entry.input2_met && load_out[load_tail].cross_entry.valid;
assign pop_store_ready = store_out[store_tail].cross_entry.cross_dep_met && store_out[store_tail].rs_entry.input1_met
                      && store_out[store_tail].rs_entry.input2_met && store_out[store_tail].cross_entry.valid
                      && commit_store;

// Setup inputs to queues
always_comb begin
    for(int i = 0; i < SS; i++) begin
        load_queue_in[i] = dispatch_entry[i];
        load_queue_in[i].cross_entry.pointer = store_head;
        load_queue_in[i].cross_entry.cross_dep_met = 1'b0;
        load_queue_in[i].cross_entry.valid = 1'b1;

        store_queue_in[i] = dispatch_entry[i];
        store_queue_in[i].cross_entry.pointer = load_head;
        store_queue_in[i].cross_entry.cross_dep_met = 1'b0;
        store_queue_in[i].cross_entry.valid = 1'b1;

        // Transparency for dependencies
        // for(int j = 0; j < CDB; j++) begin
            if(cdb_in[0].ready_for_writeback && (cdb_in[0].inst_info.rat.rd == dispatch_entry[0].rat.rs1)) begin
                load_queue_in[0].rs_entry.input1_met = 1'b1;
                store_queue_in[0].rs_entry.input1_met = 1'b1;
            end
            
            if(cdb_in[0].ready_for_writeback && (cdb_in[0].inst_info.rat.rd == dispatch_entry[0].rat.rs2)) begin
                load_queue_in[0].rs_entry.input2_met = 1'b1;
                store_queue_in[0].rs_entry.input2_met = 1'b1;
            end
         end
    //end
end

circular_queue #(.QUEUE_TYPE(super_dispatch_t), .SS(SS), .SEL_IN(LD_ST_DEPTH), .SEL_OUT(LD_ST_DEPTH),
                 .DEPTH(LD_ST_DEPTH)) 
load_queue(
    .clk(clk), .rst(rst || flush),
    .in(load_queue_in),
    .out(load_queue_out),
    .tail_out(load_tail),
    .head_out(load_head),
    // Always need to access all entries
    .reg_select_in(reg_select_queue),
    .reg_select_out(reg_select_queue),
    .reg_in(load_in),
    .reg_out(load_out),
    .in_bitmask(load_in_bit),
    .out_bitmask('1),
    .full(load_full),
    .push(push_load),
    .pop(pop_load)
);

circular_queue #(.QUEUE_TYPE(super_dispatch_t), .SS(SS), .SEL_IN(LD_ST_DEPTH), .SEL_OUT(LD_ST_DEPTH),
                 .DEPTH(LD_ST_DEPTH))
store_queue(
    .clk(clk), .rst(rst || flush),
    .in(store_queue_in),
    .out(store_queue_out),
    .tail_out(store_tail),
    .head_out(store_head),
    // Always need to access all entries
    .reg_select_in(reg_select_queue),
    .reg_select_out(reg_select_queue),
    .reg_in(store_in),
    .reg_out(store_out),
    .in_bitmask(store_in_bit),
    .out_bitmask('1),
    .full(store_full),
    .push(push_store),
    .pop(pop_store)
);

ld_st_controller_t state, next_state;

always_ff @(posedge clk) begin
    if(rst)
        state <= wait_s_load_p;
    else
        state <= next_state;
end


// Next state logic
always_comb begin
    // Depending on current wait state, prioritize load or store
    if(pop_load_ready && pop_store_ready 
       && (state == wait_s_load_p || state == wait_s_store_p)) begin
        unique case (state)
            wait_s_load_p : next_state = request_load_s;
            wait_s_store_p : next_state = request_store_s;
            default : next_state = state;
        endcase
    end
    else if(pop_load_ready && (state == wait_s_load_p || state == wait_s_store_p) && ~flush) begin
        next_state = request_load_s;
    end
    else if(pop_store_ready && (state == wait_s_load_p || state == wait_s_store_p) && ~flush) begin
        next_state = request_store_s;
    end
    else if((state == request_load_s || state == request_store_s) && dmem_resp) begin
        // Return to other wait state to prevent starvation
        unique case (state)
            request_load_s : next_state = latch_load_s;
            request_store_s : next_state = latch_store_s;
            default : next_state = state;
        endcase
    end
    else if(state == latch_load_s) begin
        next_state = wait_s_store_p;
    end
    else if(state == latch_store_s) begin
        next_state = wait_s_load_p;
    end
    else begin
        next_state = state;
    end
end

logic move_to_load, move_to_store;
assign move_to_load = (pop_load_ready && (state == wait_s_load_p || (state == wait_s_store_p && ~pop_store_ready)));
assign move_to_store = (pop_store_ready && (state == wait_s_store_p || (state == wait_s_load_p && ~pop_load_ready)));

// Modify entries up receiving updates from cdb
always_comb begin
    for(int d = 0; d < LD_ST_DEPTH; d++) begin
        load_in[d] = load_out[d];
        load_in_bit[d] = 1'b0;
        store_in[d] = store_out[d];
        store_in_bit[d] = 1'b0;
        for(int i = 0; i < CDB; i++) begin
            if(load_out[d].cross_entry.valid) begin
                // Loads - RS1
                if(cdb_in[i].ready_for_writeback && load_out[d].rat.rs1 == cdb_in[i].inst_info.rat.rd) begin
                    load_in[d].rs_entry.input1_met = 1'b1;
                    load_in_bit[d] = 1'b1;
                end

                // Loads - RS2
                if(cdb_in[i].ready_for_writeback && load_out[d].rat.rs2 == cdb_in[i].inst_info.rat.rd) begin
                    load_in[d].rs_entry.input2_met = 1'b1;
                    load_in_bit[d] = 1'b1;
                end
            end
            if(store_out[d].cross_entry.valid) begin
                // Stores - RS1
                if(cdb_in[i].ready_for_writeback && store_out[d].rat.rs1 == cdb_in[i].inst_info.rat.rd) begin
                    store_in[d].rs_entry.input1_met = 1'b1;
                    store_in_bit[d] = 1'b1;
                end

                // Stores - RS2
                if(cdb_in[i].ready_for_writeback && store_out[d].rat.rs2 == cdb_in[i].inst_info.rat.rd) begin
                    store_in[d].rs_entry.input2_met = 1'b1;
                    store_in_bit[d] = 1'b1;
                end
            end
        end
        
        // Update cross dependencies for loads
        if(load_out[d].cross_entry.valid && load_out[d].cross_entry.pointer == store_tail) begin
            load_in[d].cross_entry.cross_dep_met = 1'b1;
            load_in_bit[d] = 1'b1;
        end
        // Update cross dependencies for stores
        if(store_out[d].cross_entry.valid && store_out[d].cross_entry.pointer == load_tail) begin
            store_in[d].cross_entry.cross_dep_met = 1'b1;
            store_in_bit[d] = 1'b1;
        end

        // Invalidate old entries
        if(move_to_load && (($clog2(LD_ST_DEPTH))'(d) == load_tail)) begin
            load_in[d].cross_entry.valid = 1'b0;
            load_in_bit[d] = 1'b1;
        end
        if(move_to_store && (($clog2(LD_ST_DEPTH))'(d)) == store_tail) begin
            store_in[d].cross_entry.valid = 1'b0;
            store_in_bit[d] = 1'b1;
        end
    end
end


// Latches for response
logic [31:0] dmem_rdata_out_reg, dmem_rdata_reg;
// Latches for sending out to dram (load)
logic [31:0] cdb_rs1_register_value_reg, immediate_reg;
// Latches for sending out to dram (store)
logic [31:0] cdb_rs2_register_value_reg;

// Masked read data returned from memory appropriately
logic [31:0] dmem_rdata_masked, dmem_rdata_out, dmem_addr_latched, dmem_comb_addr_load, dmem_comb_addr_store;
logic [3:0] dmem_rmask_reg, dmem_wmask_reg;

// Info for latched instructions
super_dispatch_t entry_latch;

// Addr that held during request states
assign dmem_addr_latched = cdb_rs1_register_value_reg + immediate_reg;
// Addr computed for request states
assign dmem_comb_addr_store = lsq_reg_data.rs1_v.register_value + store_out[store_tail].inst.immediate;
assign dmem_comb_addr_load = lsq_reg_data.rs1_v.register_value + load_out[load_tail].inst.immediate;

// Logic to block the cdb if a flush
always_ff @(posedge clk) begin
    if(rst)
        block_cdb <= 1'b0;
    else begin
        if(flush && (state == request_load_s || state == request_store_s))
            block_cdb <= 1'b1;
        else if(state != request_load_s && state != request_store_s)
            block_cdb <= 1'b0;
    end
end

always_ff @(posedge clk) begin
    if(rst) begin
        dmem_rdata_out_reg <= '0;
        dmem_rdata_reg <= '0;
        dmem_rmask_reg <= '0;
        dmem_wmask_reg <= '0;

        cdb_rs1_register_value_reg <= '0;
        immediate_reg <= '0;
        cdb_rs2_register_value_reg <= '0;

        entry_latch <= '0;
    end
    else begin
        if(dmem_resp) begin
            dmem_rdata_out_reg <= dmem_rdata_out;
            dmem_rdata_reg <= dmem_rdata;
        end

        if(move_to_load && ~flush) begin
            cdb_rs1_register_value_reg <= lsq_reg_data.rs1_v.register_value;
            immediate_reg <= load_out[load_tail].inst.immediate;
            dmem_rmask_reg <= load_out[load_tail].inst.rmask << dmem_comb_addr_load[1:0];
            entry_latch <= load_out[load_tail];
        end

        if(move_to_store && ~flush) begin
            cdb_rs1_register_value_reg <= lsq_reg_data.rs1_v.register_value;
            cdb_rs2_register_value_reg <= lsq_reg_data.rs2_v.register_value;
            immediate_reg <= store_out[store_tail].inst.immediate;
            dmem_wmask_reg <= store_out[store_tail].inst.wmask << dmem_comb_addr_store[1:0];
            entry_latch <= store_out[store_tail];
        end
    end
end

logic [31:0] shift_amt;
logic signed [31:0] dmem_rdata_signed;
assign shift_amt =  8*(dmem_addr_latched[1:0]);
assign dmem_rdata_signed = signed'(dmem_rdata_masked);

// Used on data response
always_comb begin
    if(~entry_latch.inst.is_signed) begin
        dmem_rdata_out = unsigned'(dmem_rdata_signed >> shift_amt);
    end
    else begin
        dmem_rdata_out = unsigned'(dmem_rdata_signed >>> shift_amt);
    end
    for(int i = 0; i < 4; i++) begin
        // Differentiate between signed and unsigned
        if(~entry_latch.inst.is_signed) begin
            dmem_rdata_masked[8*i+:8] = dmem_rdata[8*i+:8] & {8{dmem_rmask_reg[i]}}; 
        end
        else begin
            if(dmem_rmask_reg[i])
                dmem_rdata_masked[8*i+:8] = dmem_rdata[8*i+:8]; 
            else begin
                if(i > 0)
                    dmem_rdata_masked[8*i+:8] = {8{dmem_rdata_masked[(8*i)-1]}}; 
                else
                    dmem_rdata_masked[8*i+:8] = 8'b0;
            end
        end
    end
end


always_comb begin
    // Send out to data cache based on state of controller
    unique case (state)
    wait_s_load_p, wait_s_store_p : begin
        dmem_addr = 'x;
        dmem_rmask = 1'b0;
        dmem_wmask = 4'b0;
        dmem_wdata = 'x;
    end
    request_load_s : begin
        dmem_addr = dmem_addr_latched;
        dmem_rmask = 1'b1;
        dmem_wmask = 4'b0;
        dmem_wdata = 'x;
    end
    request_store_s : begin
        dmem_addr = dmem_addr_latched; // NOT CORRECT!!
        dmem_rmask = 1'b0;
        dmem_wmask = dmem_wmask_reg;
        dmem_wdata = cdb_rs2_register_value_reg;
    end
    default : begin
        dmem_addr = 'x;
        dmem_rmask = 1'b0;
        dmem_wmask = 4'b0;
        dmem_wdata = 'x;
    end
    endcase

    if(move_to_load) begin
        pop_load = 1'b1;
        pop_store = 1'b0;
    end
    else if (move_to_store) begin
        pop_load = 1'b0;
        pop_store = 1'b1;
    end
    else begin
        pop_load = 1'b0;
        pop_store = 1'b0;
    end

    // Send out regfile requests
    if(move_to_load && ~flush) begin
        lsq_request.rs1_s = load_out[load_tail].rat.rs1;
        lsq_request.rs2_s = 'x;
        lsq_request.rd_s = 'x;
        lsq_request.rd_en = 1'b0;
        lsq_request.rd_v = 'x;
        cdb_out.inst_info = 'x;
        cdb_out.register_value = 'x;
        cdb_out.ready_for_writeback = 1'b0;
    end
    else if(move_to_store && ~flush) begin
        lsq_request.rs1_s = store_out[store_tail].rat.rs1;
        lsq_request.rs2_s = store_out[store_tail].rat.rs2;
        lsq_request.rd_s = 'x;
        lsq_request.rd_en = 1'b0;
        lsq_request.rd_v = 'x;
        cdb_out.inst_info = 'x;
        cdb_out.register_value = 'x;
        cdb_out.ready_for_writeback = 1'b0;
    end
    else if(state == latch_load_s && ~block_cdb) begin
        lsq_request.rs1_s = 'x;
        lsq_request.rs2_s = 'x;
        lsq_request.rd_s = 'x;
        lsq_request.rd_en = 1'b0;
        lsq_request.rd_v = 'x;
        cdb_out.inst_info = entry_latch;
        cdb_out.register_value = dmem_rdata_out_reg;
        cdb_out.ready_for_writeback = 1'b1;
        cdb_out.inst_info.rvfi.rd_wdata = dmem_rdata_out_reg;
        cdb_out.inst_info.rvfi.rs1_rdata = cdb_rs1_register_value_reg;
        cdb_out.inst_info.rvfi.rs2_rdata = '0;
        cdb_out.inst_info.rvfi.mem_rdata = dmem_rdata_reg;
        cdb_out.inst_info.rvfi.mem_wdata = 'x;
        cdb_out.inst_info.rvfi.mem_rmask = dmem_rmask_reg; 
        cdb_out.inst_info.rvfi.mem_addr = cdb_rs1_register_value_reg + immediate_reg;
    end
    else if(state == latch_store_s && ~block_cdb) begin
        lsq_request.rs1_s = 'x;
        lsq_request.rs2_s = 'x;
        lsq_request.rd_s = 'x;
        lsq_request.rd_en = 1'b0;
        lsq_request.rd_v = 'x;
        cdb_out.inst_info = entry_latch;
        cdb_out.register_value = 'x;
        cdb_out.ready_for_writeback = 1'b1;
        cdb_out.inst_info.rvfi.rd_addr = '0;
        cdb_out.inst_info.rvfi.rd_wdata = 'x;
        cdb_out.inst_info.rvfi.rs1_rdata = cdb_rs1_register_value_reg;
        cdb_out.inst_info.rvfi.rs2_rdata = cdb_rs2_register_value_reg;
        cdb_out.inst_info.rvfi.mem_rdata = 'x;
        cdb_out.inst_info.rvfi.mem_wdata = cdb_rs2_register_value_reg << 8*dmem_addr_latched[1:0];
        cdb_out.inst_info.rvfi.mem_wmask = dmem_wmask_reg;
        cdb_out.inst_info.rvfi.mem_addr = cdb_rs1_register_value_reg + immediate_reg;
    end
    else begin
        lsq_request.rs1_s = 'x;
        lsq_request.rs2_s = 'x;
        lsq_request.rd_s = 'x;
        lsq_request.rd_en = 1'b0;
        lsq_request.rd_v = 'x;
        cdb_out.inst_info = 'x;
        cdb_out.register_value = 'x;
        cdb_out.ready_for_writeback = 1'b0;
    end
end

endmodule : load_store_queue
