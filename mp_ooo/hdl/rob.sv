module rob
    import rv32i_types::*;
    #(
        parameter SS = 2,
        parameter ROB_DEPTH = 8
    )(
    ////// INPUTS:
        input logic clk,
        input logic rst, 
             
        // dispatched instructions
        input dispatch_reservation_t dispatch_info [SS],
    
        input logic commit_ready,
        // rob is full
        output logic [SS-1:0] rob_full,
        // rob is empty
        output logic [SS-1:0] rob_empty,
    
    ////// OUTPUTS:
        // when to update regfile
        output logic [SS-1:0] write_from_rob,
        // rob id are sent out
        output logic [$clog2(ROB_DEPTH)-1:0] rob_id_out[SS],
        // destination regs for the instr
        output logic [4:0] rob_dest_reg[SS]
    );
    
    // head & tail pointers for ROB entries
    logic [$clog2(ROB_DEPTH)-1:0] head, tail;
    logic push_to_rob, pop_from_rob;
    
    // ROB receives data from CDB and updates commit flag in circular queue
    circular_queue #(.QUEUE_TYPE(rob_t), .DEPTH(ROB_DEPTH)) rob_dut(.push(push_to_rob), .pop(pop_from_rob), .reg_select_out(rob_id_out), .reg_out(), .head_out(head), .tail_out(tail));
    
    always_ff @(posedge clk)begin
        if (rst) begin
            // Reset logic
            for (int i = 0; i < SS; i++) begin
                write_from_rob[i] <= 0;
                rob_id_out[i] <= 0;
                rob_dest_reg[i] <= 0;
            end
            pop_from_rob <= '0;
        end
        else begin
            // Dispatch:
            for(int i = 0; i < SS; i++)begin
                // setting up to read the first SS entries in the rob
                reg_select_out[i] <= i;
    
                // Check each ss slot if an instruction has been dispatched
                if (dispatch_info[i].inst.valid && !rob_full[i] && push_to_rob)begin     
                    // Regfile should be updated w/ new phys reg mapping
                    write_from_rob[i] <= '1;
                    rob_id_out[i] <= head + i;
                    rob_dest_reg[i] <= dispatch_info[i].rat.rd; // Need to get PR not ISA reg
                end
                else
                    write_from_rob <= '0;
            end
    
            // Commmit:
            pop_from_rob <= commit_ready && !rob_empty[0]; //pop from queue if instr at the head is ready to commit
        end
    end
    endmodule : rob