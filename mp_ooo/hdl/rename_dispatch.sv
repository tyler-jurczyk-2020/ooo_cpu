// rename/dispatch shit
module rename_dispatch
import rv32i_types::*;
(
////// INPUT:
    input logic clk, rst,
    // RAT
    input logic [5:0] rat_rs1 [2], rat_rs2 [2],

    // Instruction Queue
    input instruction_info_reg_t instruction [2],
    input logic inst_q_empty,

    // Free List
    input [5:0] free_list_regs [2],

    // Reservation Station
    input logic rs_full,


////// Output
    // RAT
    output logic modify_rat,
    output logic [5:0] rat_dest [2],
    output logic [4:0] isa_rs1 [2], isa_rs2 [2],

    // Instruction Queue
    output logic pop_inst_q,

    // Free List
    output logic pop_free_list,

    // ROB
    output rob_t updated_rob

    // Reservation Station
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
        isa_rs1[0] = instruction[0].rs1_s;
        isa_rs2[0] = instruction[0].rs2_s;

        isa_rs1[1] = instruction[1].rs1_s;
        isa_rs2[1] = instruction[1].rs2_s;

        rat_dest = free_list_regs;
        modify_rat = 1'b1;
    end
    else begin
        for(int i = 0; i < 2; i++) begin
            isa_rs1[i] = 'x;
            isa_rs2[i] = 'x;
            rat_dest[i] = 'x;
        end
        modify_rat = 1'b0;
    end
end

// Pop from the free list and read from instruction queue:
assign pop_free_list = ~inst_q_empty && ~rs_full;
assign pop_inst_q = pop_free_list;

endmodule : rename_dispatch
