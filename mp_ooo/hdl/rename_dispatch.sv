// rename/dispatch shit
module rename_dispatch
import rv32i_types::*;
#(
    parameter SS = 2
)
(
////// INPUT:
    input logic clk, rst,
    // RAT
    input logic [5:0] rat_rs1 [SS], rat_rs2 [SS],

    // Instruction Queue
    input instruction_info_reg_t instruction [SS],
    input logic inst_q_empty,

    // Free List
    input [5:0] free_list_regs [SS],

    // Reservation Station
    input logic rs_full,


////// Output
    // RAT
    output logic modify_rat,
    output logic [5:0] rat_dest [SS],
    output logic [4:0] isa_rs1 [SS], isa_rs2 [SS], isa_rd[SS],

    // Instruction Queue
    output logic pop_inst_q,

    // Free List
    output logic pop_free_list,

    // ROB
    output rob_t updated_rob,

    // Reservation Station
    output logic rs_enable,
    output dispatch_reservation_t rs_entries [SS]
);

logic avail_inst;
always_ff @(posedge clk) begin
    if(rst)
        avail_inst <= 1'b0;
    else
        avail_inst <= pop_free_list;
end

// Lookup RAT source regs and modify dest reg:
always_comb begin
    if(avail_inst) begin
        // Update RAT
        for(int i = 0; i < SS; i++) begin
            isa_rs1[i] = instruction[i].rs1_s;
            isa_rs2[i] = instruction[i].rs2_s;
            isa_rd[i] = instruction[i].rd_s;
        end

        rat_dest = free_list_regs;
        modify_rat = 1'b1;
        
        // Setup entries going to reservation station
        for(int i = 0; i < SS; i++) begin
            // RVFI setup
            rs_entries[i].rvfi.valid = instruction[i].valid;
            rs_entries[i].rvfi.order = 64'b0; // Need to put actual order here
            rs_entries[i].rvfi.inst = instruction[i].inst;
            rs_entries[i].rvfi.rs1_addr = instruction[i].rs1_s;
            rs_entries[i].rvfi.rs2_addr = instruction[i].rs2_s;
            rs_entries[i].rvfi.rs1_rdata = 'x;
            rs_entries[i].rvfi.rs2_rdata = 'x;
            rs_entries[i].rvfi.rd_addr = instruction[i].rd_s;
            rs_entries[i].rvfi.rd_wdata = 'x;
            rs_entries[i].rvfi.pc_rdata = instruction[i].pc_curr;
            rs_entries[i].rvfi.pc_wdata = instruction[i].pc_next;
            rs_entries[i].rvfi.mem_addr = 'x;
            // Need to compute rmask/wmask based on type of mem op
            rs_entries[i].rvfi.mem_rmask = 'x;
            rs_entries[i].rvfi.mem_wmask = 'x;
            rs_entries[i].rvfi.mem_rdata = 'x;
            rs_entries[i].rvfi.mem_wdata = 'x;

            //Instruction setup
            rs_entries[i].inst = instruction[i];

            //Rat Registers
            rs_entries[i].rat.rs1 = rat_rs1[i];
            rs_entries[i].rat.rs2 = rat_rs2[i];
            rs_entries[i].rat.rd = free_list_regs[i];
        end
    end
    else begin
        for(int i = 0; i < SS; i++) begin
            isa_rs1[i] = 'x;
            isa_rs2[i] = 'x;
            isa_rd[i] = 'x;
            rat_dest[i] = 'x;
        end
        modify_rat = 1'b0;

        // Setup entries going to reservation station
        for(int i = 0; i < SS; i++) begin 
                // RVFI setup
                rs_entries[i].rvfi.valid = 'x; // SOUMIL IS SLOW
                rs_entries[i].rvfi.order = 'x; // SOUMIL IS SLOW // Need to put actual order here
                rs_entries[i].rvfi.inst = 'x;
                rs_entries[i].rvfi.rs1_addr = 'x;
                rs_entries[i].rvfi.rs2_addr = 'x;
                rs_entries[i].rvfi.rs1_rdata = 'x;
                rs_entries[i].rvfi.rs2_rdata = 'x;
                rs_entries[i].rvfi.rd_addr = 'x;
                rs_entries[i].rvfi.rd_wdata = 'x;
                rs_entries[i].rvfi.pc_rdata = 'x;
                rs_entries[i].rvfi.pc_wdata = 'x;
                rs_entries[i].rvfi.mem_addr = 'x;
                // Need to compute rmask/wmask based on type of mem op
                rs_entries[i].rvfi.mem_rmask = 'x;
                rs_entries[i].rvfi.mem_wmask = 'x;
                rs_entries[i].rvfi.mem_rdata = 'x;
                rs_entries[i].rvfi.mem_wdata = 'x;

                //Instruction setup
                rs_entries[i].inst = 'x;

                //Rat Registers
                rs_entries[i].rat.rs1 = 'x;
                rs_entries[i].rat.rs2 = 'x;
                rs_entries[i].rat.rd = 'x;
        end
    end
end

// Pop from the free list and read from instruction queue:
assign pop_free_list = ~inst_q_empty && ~rs_full;
assign pop_inst_q = pop_free_list;
assign rs_enable = avail_inst;

endmodule : rename_dispatch
