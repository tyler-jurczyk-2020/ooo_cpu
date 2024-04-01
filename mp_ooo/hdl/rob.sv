module rob
import rv32i_types::*;
#(
    parameter SS = 2,
    parameter ROB_DEPTH = 8
)(
    input logic clk,
    input logic rst, 
         
    // dispatched instructions
    input dispatch_reservation_t dispatch_info [SS],
    // rob entries
    input rob_t rob_entry, 

    // pop signal from instr queue
    input logic rob_push,

    // rob is full
    output logic [SS-1:0] rob_full,
    // rob is empty
    output logic [SS-1:0] rob_empty,

    // outputs for updating regfile:
    // when to update regfile
    output logic [SS-1:0] regfile_update_en,
    // rob id are sent out
    output logic [$clog2(ROB_DEPTH)-1:0] rob_id_out[SS],
    // destination regs for the instr
    output logic [4:0] dest_reg[SS]
);

// head & tail pointers for ROB entries
logic [$clog2(ROB_DEPTH)-1:0] head, tail;
logic push_to_rob;

rob_t regout[SS];

// ROB receives data from CDB and updates commit flag in circular queue
circular_queue #(.QUEUE_TYPE(rob_t), .DEPTH(ROB_DEPTH)) rob_dut(.push(push_to_rob), .reg_select_out(rob_id_out), .reg_out(regout), .head_out(head), .tail_out(tail));

always_comb begin
    // reset update signals at the begining of each cycle 
    regfile_update_en <= '0;

    // Dispatch Phase:
    for(int i = 0; i < SS; i++)begin
        if (dispatch_info[i].inst.valid && !rob_full[i] && rob_push)begin
            // set update signal & give rob id & dest reg
            regfile_update_en[i] <= '1;
            rob_id_out[i] <= tail + i[$clog2(ROB_DEPTH)-1:0];
            // dest_reg[i] <= dispatch_info[i].inst.rd; // Need to get PR not ISA reg

            push_to_rob <= '1;  // push new rob entry for dispatched instr
        end
    end
end

endmodule : rob
