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
    input physical_reg_request_t lsq_reg_data,

    // Output to cdb
    output fu_output_t cdb_out,
    
    // Read off cdb
    input cdb_t cdb_in

);

logic push_load, push_store, pop_load_ready, pop_store_ready, pop_load, pop_store;
logic [$clog2(LD_ST_DEPTH)-1:0] load_tail, store_tail;
logic load_full, store_full;

// Hardcoded reg select
logic [$clog2(LD_ST_DEPTH)-1:0] reg_select_queue [LD_ST_DEPTH];
always_comb begin
    for(int i = 0; i < LD_ST_DEPTH; i++) begin
        reg_select_queue[i] = '0;
    end
end

// Input into queues
super_dispatch_t load_queue_in [SS], store_queue_in [SS];

// Entries of the queue to fw
logic [LD_ST_DEPTH-1:0] load_in_bit, store_in_bit;
super_dispatch_t load_in [LD_ST_DEPTH], load_out [LD_ST_DEPTH];
super_dispatch_t store_in [LD_ST_DEPTH], store_out [LD_ST_DEPTH];

// For now only properly support non-superscalar
assign push_load = avail_inst && ~load_full && dispatch_entry[0].inst.rmask != 4'b0;
assign push_store = avail_inst && ~store_full && dispatch_entry[0].inst.wmask != 4'b0;
assign pop_load_ready = load_out[load_tail].cross_tail.cross_dep_met && load_out[load_tail].rs_entry.input1_met
                    && load_out[load_tail].rs_entry.input2_met;
assign pop_store_ready = store_out[store_tail].cross_tail.cross_dep_met && store_out[store_tail].rs_entry.input1_met
                      && store_out[store_tail].rs_entry.input2_met;

// Setup inputs to queues
always_comb begin
    for(int i = 0; i < SS; i++) begin
        load_queue_in[i] = dispatch_entry[i];
        load_queue_in[i].cross_tail.pointer = store_tail;
        load_queue_in[i].cross_tail.cross_dep_met = 1'b0;

        store_queue_in[i] = dispatch_entry[i];
        store_queue_in[i].cross_tail.pointer = load_tail;
        store_queue_in[i].cross_tail.cross_dep_met = 1'b0;
    end
end

circular_queue #(.QUEUE_TYPE(super_dispatch_t), .SS(SS), .SEL_IN(LD_ST_DEPTH), .SEL_OUT(LD_ST_DEPTH),
                 .DEPTH(LD_ST_DEPTH)) 
load_queue(
    .clk(clk), .rst(rst || flush),
    .in(dispatch_entry),
    .tail_out(load_tail),
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
    .in(dispatch_entry),
    .tail_out(store_tail),
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
    else if(pop_load_ready && (state == wait_s_load_p || state == wait_s_store_p)) begin
        next_state = request_load_s;
    end
    else if(pop_store_ready && (state == wait_s_load_p || state == wait_s_store_p)) begin
        next_state = request_store_s;
    end
    else if((state == request_load_s || state == request_store_s) && dmem_resp) begin
        // Return to other wait state to prevent starvation
        unique case (state)
            request_load_s : next_state = wait_s_store_p;
            request_store_s : next_state = wait_s_load_p;
            default : next_state = state;
        endcase
    end
    else begin
        next_state = state;
    end
end

// Modify entries up receiving updates from cdb
always_comb begin
    for(int i = 0; i < LD_ST_DEPTH; i++) begin
        for(int j = 0; j < N_ALU; j++) begin
            for(int k = 0; k < N_MUL; k++) begin
                // Loads - RS1
                if(load_out[i].rat.rs1 == cdb_in.alu_out[j].inst_info.rat.rd) begin
                    load_in[i].rs_entry.input1_met = 1'b1;
                    load_in_bit[i] = 1'b1;
                end
                else if(load_out[i].rat.rs1 == cdb_in.lsq_out.inst_info.rat.rd) begin
                    load_in[i].rs_entry.input1_met = 1'b1;
                    load_in_bit[i] = 1'b1;
                end
                else if(load_out[i].rat.rs1 == cdb_in.mul_out[j].inst_info.rat.rd) begin
                    load_in[i].rs_entry.input1_met = 1'b1;
                    load_in_bit[i] = 1'b1;
                end
                else begin
                    load_in[i].rs_entry.input1_met = 'x;
                    load_in_bit[i] = 1'b0;
                end

                if(load_out[i].rat.rs2 == cdb_in.alu_out[j].inst_info.rat.rd) begin
                    load_in[i].rs_entry.input2_met = 1'b1;
                    load_in_bit[i] = 1'b1;
                end
                else if(load_out[i].rat.rs2 == cdb_in.mul_out[j].inst_info.rat.rd) begin
                    load_in[i].rs_entry.input2_met = 1'b1;
                    load_in_bit[i] = 1'b1;
                end
                else if(load_out[i].rat.rs2 == cdb_in.lsq_out.inst_info.rat.rd) begin
                    load_in[i].rs_entry.input2_met = 1'b1;
                    load_in_bit[i] = 1'b1;
                end
                else begin
                    load_in[i].rs_entry.input2_met = 'x;
                    load_in_bit[i] = 1'b0;
                end

                // Stores
                if(store_out[i].rat.rs1 == cdb_in.alu_out[j].inst_info.rat.rd) begin
                    store_in[i].rs_entry.input1_met = 1'b1;
                    store_in_bit[i] = 1'b1;
                end
                else if(store_out[i].rat.rs1 == cdb_in.mul_out[j].inst_info.rat.rd) begin
                    store_in[i].rs_entry.input1_met = 1'b1;
                    store_in_bit[i] = 1'b1;
                end
                else if(store_out[i].rat.rs1 == cdb_in.lsq_out.inst_info.rat.rd) begin
                    store_in[i].rs_entry.input1_met = 1'b1;
                    store_in_bit[i] = 1'b1;
                end
                else begin
                    store_in[i].rs_entry.input1_met = 'x;
                    store_in_bit[i] = 1'b0;
                end

                if(store_out[i].rat.rs2 == cdb_in.alu_out[j].inst_info.rat.rd) begin
                    store_in[i].rs_entry.input2_met = 1'b1;
                    store_in_bit[i] = 1'b1;
                end
                else if(store_out[i].rat.rs2 == cdb_in.mul_out[j].inst_info.rat.rd) begin
                    store_in[i].rs_entry.input2_met = 1'b1;
                    store_in_bit[i] = 1'b1;
                end
                else if(store_out[i].rat.rs2 == cdb_in.lsq_out.inst_info.rat.rd) begin
                    store_in[i].rs_entry.input2_met = 1'b1;
                    store_in_bit[i] = 1'b1;
                end
                else begin
                    store_in[i].rs_entry.input2_met = 'x;
                    store_in_bit[i] = 1'b0;
                end
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
        dmem_addr = load_out[load_tail].inst.immediate;
        dmem_rmask = 1'b1;
        dmem_wmask = 4'b0;
        dmem_wdata = 'x;
    end
    request_store_s : begin
        dmem_addr = store_out[store_tail].inst.immediate;
        dmem_rmask = 1'b0;
        dmem_wmask = store_out[store_tail].inst.wmask;
        dmem_wdata = lsq_reg_data.rd_v.register_value;
    end
    endcase

    // Send out regfile requests
    if(request_load_s) begin
        pop_store = 1'b0;
        lsq_request.rs1_s = load_out[load_tail].rat.rs1;
        lsq_request.rs2_s = 'x;
        lsq_request.rd_s = 'x;
        lsq_request.rd_en = 1'b0;
        lsq_request.rd_v = 'x;
        if(dmem_resp) begin
            pop_load = 1'b1;
            cdb_out.inst_info = load_out[load_tail].inst;
            cdb_out.register_value = dmem_rdata;
            cdb_out.ready_for_writeback = 1'b1;
        end
        else begin
            pop_load = 1'b0;
            cdb_out.inst_info = 'x;
            cdb_out.register_value = 'x;
            cdb_out.ready_for_writeback = 1'b0;
        end
    end
    else if(request_store_s) begin
        pop_load = 1'b0;
        pop_store = 1'b1;
        lsq_request.rs1_s = store_out[store_tail].rat.rs1;
        lsq_request.rs2_s = store_out[store_tail].rat.rs2;
        lsq_request.rd_s = 'x;
        lsq_request.rd_en = 1'b0;
        lsq_request.rd_v = 'x;
    end
    else begin
        pop_load = 1'b0;
        pop_store = 1'b0;
        lsq_request.rs1_s = 'x;
        lsq_request.rs2_s = 'x;
        lsq_request.rd_s = 'x;
        lsq_request.rd_en = 1'b0;
        lsq_request.rd_v = 'x;
    end
end

endmodule : load_store_queue