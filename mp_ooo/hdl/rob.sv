module rob
    import rv32i_types::*;
    #(
        parameter SS = 2,
        parameter ROB_DEPTH = 7
    )(
    ////// INPUTS:
        input clk,
        input rst, 
        // dispatched instructions
        input logic avail_inst,
        input dispatch_reservation_t dispatch_info [SS],
    
    ////// OUTPUTS:
        // when to update regfile
        output logic write_from_rob[SS],
        // rob id are sent out
        output logic [$clog2(ROB_DEPTH)-1:0] rob_id_next [SS],
        // destination regs for the instr
        output logic [5:0] rob_dest_reg[SS],
        // updated RVFI order
        output dispatch_reservation_t rob_entries_to_commit [SS]
    );
    
    // head & tail pointers for ROB entries
    logic [$clog2(ROB_DEPTH)-1:0] head, tail;
    logic push_to_rob, pop_from_rob;
    dispatch_reservation_t inspect_queue [SS];
    logic rob_full, rob_empty;

    logic [$clog2(ROB_DEPTH)-1:0] rob_id_out[SS];
    
    // ROB receives data from CDB and updates commit flag in circular queue
    circular_queue #(.SS(SS), .QUEUE_TYPE(dispatch_reservation_t), .DEPTH(ROB_DEPTH)) rob_dut(.clk(clk), .rst(rst), .push(avail_inst), .pop(pop_from_rob), 
    .reg_select_out(rob_id_out), .reg_out(inspect_queue), .head_out(head), .tail_out(tail),
    .full(rob_full), .empty(rob_empty));
    
    always_comb begin
        // Dispatch:
        for(int i = 0; i < SS; i++)begin
            // setting up to read the first SS entries in the rob
            // inspect_queue[i] = i; // Don't really know what this does
            pop_from_rob &= inspect_queue[i].rob.commit && !rob_empty; //pop from queue if instr at the head is ready to commit
            rob_id_next[i] = head + i[$clog2(ROB_DEPTH)-1:0];

            // Check each ss slot if an instruction has been dispatched
            if (dispatch_info[i].inst.valid && !rob_full && avail_inst)begin     
                // Regfile should be updated w/ new phys reg mapping
                write_from_rob[i] = '1;
                rob_id_out[i] = tail + i[$clog2(ROB_DEPTH)-1:0];
                rob_dest_reg[i] = dispatch_info[i].rat.rd; // Need to get PR not ISA reg
            end
            else begin
                write_from_rob[i] = '0;
                for(int i = 0; i < SS; i++) begin
                    rob_id_out[i] = 'x;
                    rob_dest_reg[i] = 'x; 
                end
            end
        end
    end

    // counting order when we commit 
    logic [63:0] order_counter;
    always_comb begin
        for(int i = 0; i < SS; i++) begin
            if(pop_from_rob) begin
                rob_entries_to_commit[i] = inspect_queue[i];
                rob_entries_to_commit[i].rvfi.order = order_counter + {32'b0, i};
                // Send some signal to tell rrat to commit above entries
            end
            else
                rob_entries_to_commit[i] = 'x;
        end
    end
    
    always_ff @(posedge clk) begin
        if(rst)
           order_counter <= 64'b0; 
        else if(pop_from_rob) begin
            // Set order on rvfi struct and commit to rrat (checking the tail)
            order_counter <= order_counter + 1'd1;
        end
    end
    
    endmodule : rob
