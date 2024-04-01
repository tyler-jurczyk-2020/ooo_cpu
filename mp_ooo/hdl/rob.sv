module rob
    import rv32i_types::*;
    #(
        parameter SS = 2,
        parameter ROB_DEPTH = 8
    )(
    ////// INPUTS:
        input clk,
        input rst, 
        // dispatched instructions
        input dispatch_reservation_t dispatch_info [SS],
    
    ////// OUTPUTS:
        // when to update regfile
        output logic [SS-1:0] write_from_rob,
        // rob id are sent out
        output logic [$clog2(ROB_DEPTH)-1:0] rob_id_out[SS],
        // destination regs for the instr
        output logic [5:0] rob_dest_reg[SS]
    );
    
    // head & tail pointers for ROB entries
    logic [$clog2(ROB_DEPTH)-1:0] head, tail;
    logic push_to_rob, pop_from_rob;
    dispatch_reservation_t inspect_queue [SS];
    logic rob_full, rob_empty;
    
    // ROB receives data from CDB and updates commit flag in circular queue
    circular_queue #(.QUEUE_TYPE(dispatch_reservation_t), .DEPTH(ROB_DEPTH)) rob_dut(.clk(clk), .rst(rst), .push(push_to_rob), .pop(pop_from_rob), 
    .reg_select_out(rob_id_out), .reg_out(inspect_queue), .head_out(head), .tail_out(tail),
    .full(rob_full), .empty(rob_empty));
    
    always_comb begin
        // Dispatch:
        for(int i = 0; i < SS; i++)begin
            // setting up to read the first SS entries in the rob
            // inspect_queue[i] = i; // Don't really know what this does
            pop_from_rob &= inspect_queue[i].rob.commit && !rob_empty; //pop from queue if instr at the head is ready to commit

            // Check each ss slot if an instruction has been dispatched
            if (dispatch_info[i].inst.valid && !rob_full && push_to_rob)begin     
                // Regfile should be updated w/ new phys reg mapping
                write_from_rob = '1;
                rob_id_out[i] = tail + i[$clog2(ROB_DEPTH)-1:0];
                rob_dest_reg[i] = dispatch_info[i].rat.rd; // Need to get PR not ISA reg
            end
            else begin
                write_from_rob = '0;
                for(int i = 0; i < SS; i++) begin
                    rob_id_out[i] = 'x;
                    rob_dest_reg[i] = 'x; 
                end
            end
        end
    end
    endmodule : rob
