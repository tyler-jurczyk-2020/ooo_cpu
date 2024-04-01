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
        input logic avail_inst,
        input dispatch_reservation_t dispatch_info [SS],
    
    ////// OUTPUTS:
        // when to update regfile
        output logic [SS-1:0] write_from_rob,
        // rob id are sent out
        output logic [$clog2(ROB_DEPTH)-1:0] rob_id_next [SS],
        // destination regs for the instr
        output logic [5:0] rob_dest_reg[SS] 
        // setting RVFI order
        // output logic [63:0] rvfi_order[SS]
    );
    
    // head & tail pointers for ROB entries
    logic [$clog2(ROB_DEPTH)-1:0] head, tail;
    logic pop_from_rob;
    dispatch_reservation_t inspect_queue [SS];
    logic rob_full, rob_empty;

    logic [$clog2(ROB_DEPTH)-1:0] rob_id_out[SS];
    
    // ROB receives data from CDB and updates commit flag in circular queue
    circular_queue #(.QUEUE_TYPE(dispatch_reservation_t), .DEPTH(ROB_DEPTH)) rob_dut(.clk(clk), .rst(rst), .push(avail_inst), .pop(pop_from_rob), 
    .reg_select_out(rob_id_out), .reg_out(inspect_queue), .head_out(head), .tail_out(tail),
    .full(rob_full), .empty(rob_empty));
    
    always_comb begin
        // Dispatch:
        for(int i = 0; i < SS; i++)begin
            // setting up to read the first SS entries in the rob
            pop_from_rob &= inspect_queue[i].rob.commit && !rob_empty; //pop from queue if instr at the head is ready to commit
            rob_id_next[i] = head + i[$clog2(ROB_DEPTH)-1:0];

            // Check each ss slot if an instruction has been dispatched
            if (dispatch_info[i].inst.valid && !rob_full && avail_inst)begin     
                // Regfile should be updated w/ new phys reg mapping
                write_from_rob = '1;
                rob_id_out[i] = tail + i[$clog2(ROB_DEPTH)-1:0];
                rob_dest_reg[i] = dispatch_info[i].rat.rd; // Need to get PR not ISA reg
            end
            // not updating regfile so we dont care what data is there
            else begin
                write_from_rob = '0;
                for(int i = 0; i < SS; i++) begin
                    rob_id_out[i] = 'x;
                    rob_dest_reg[i] = 'x; 
                end
            end
        end
    end
    logic [63:0] rvfi_order_counter;
   // when committing, set RVFI order
    // always_ff @(posedge clk) begin
    //     if (rst) 
    //         rvfi_order_counter <= '0;
        
    //     else if (pop_from_rob) begin
    //         // when commiting increase RVFI order
    //         rvfi_order_counter <= rvfi_order_counter + 1;
    //         // set RVFI order for committed instructions
    //         for (int i = 0; i < SS; i++) begin
    //             if (inspect_queue[i].rob.commit) 
    //                 rvfi_order[i] <= rvfi_order_counter;
    //         end
    //     end
    // end

    endmodule : rob
