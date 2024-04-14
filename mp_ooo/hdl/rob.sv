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
        input super_dispatch_t dispatch_info [SS],
        // commit signal sent in by the functional unit
        input cdb_t cdb,
    ////// OUTPUTS:
        // flush on mispredict
        output logic flush,
        // rob id are sent out
        output logic [$clog2(ROB_DEPTH)-1:0] rob_id_next [SS],
        // updated RVFI order
        output super_dispatch_t rob_entries_to_commit [SS],
        // send out full rob
        output logic rob_full,
        // pop from rob queue
        output logic pop_from_rob
    );
    
    // head & tail pointers for ROB entries
    logic [$clog2(ROB_DEPTH)-1:0] head, tail;
    logic push_to_rob;
    super_dispatch_t inspect_queue [SS];
    logic rob_empty;

    logic [$clog2(ROB_DEPTH)-1:0] rob_id_out[SS];
    
    logic [$clog2(ROB_DEPTH)-1:0] rob_id_reg_select [N_ALU + N_MUL];
    super_dispatch_t rob_entry_in [N_ALU + N_MUL];
    logic [(N_ALU + N_MUL)-1:0] bitmask;
    logic [SS-1:0] out_bitmask;
    // ROB receives data from cdb and updates commit flag in circular queue
    circular_queue #(.SS(SS), .SEL_IN(N_ALU + N_MUL), .SEL_OUT(SS), .QUEUE_TYPE(super_dispatch_t), .DEPTH(ROB_DEPTH)) rob_dut(.clk(clk), .rst(rst || flush), 
    .in(dispatch_info), .push(avail_inst), .pop(pop_from_rob), 
    .reg_select_out(rob_id_out), .flush(flush),
    .reg_out(inspect_queue), .reg_select_in(rob_id_reg_select), .reg_in(rob_entry_in), .in_bitmask(bitmask), .out_bitmask(out_bitmask),// One hot bitmask
    .head_out(head), .tail_out(tail), .full(rob_full), .empty(rob_empty),
    .backup_freelist());


    // 1. determine whether we need to branch (need to figure out whether to inform fetcher to    
    // fetch something else and whether to signal global flusher)      

    // if there is a difference in whether we predicted branch and whether to take a branch, you have to flush
    // (XOR)

    always_comb begin
        // ALU
        for(int i = 0; i < N_ALU; i++) begin
            out_bitmask[i] = 1'b1;


            if(cdb.alu_out[i].ready_for_writeback) begin
                rob_id_reg_select[i] = cdb.alu_out[i].inst_info.rob.rob_id[2:0]; // Need to fix
                rob_entry_in[i] = cdb.alu_out[i].inst_info;
                rob_entry_in[i].rob.fu_value = cdb.alu_out[i].register_value; 
                if(cdb.alu_out[i].inst_info.inst.is_branch && cdb.alu_out[i].branch_result) begin
                    rob_entry_in[i].rob.branch_enable = '1; 
                end
                else begin
                    rob_entry_in[i].rob.branch_enable = '0; 
                end

                if(cdb.alu_out[i].inst_info.inst.is_branch && (cdb.alu_out[i].branch_result ^ cdb.alu_out[i].inst_info.inst.predict_branch)) begin
                    rob_entry_in[i].rob.mispredict = '1; 
                end
                else begin
                    rob_entry_in[i].rob.mispredict = '0; 
                end
                
                rob_entry_in[i].rob.commit = '1; 
                bitmask[i] = 1'b1; 
            end
            // to fix lint warnings
            else begin
                rob_id_reg_select[i] = 'x;
                rob_entry_in[i] = 'x;
                bitmask[i] = 1'b0;
            end
        end

        //MUL
        for(int i = 0; i < N_MUL; i++) begin
            out_bitmask[N_ALU + i] = 1'b1;
            if(cdb.mul_out[i].ready_for_writeback) begin
                rob_id_reg_select[N_ALU + i] = cdb.mul_out[i].inst_info.rob.rob_id[2:0]; // Need to fix
                rob_entry_in[N_ALU + i] = cdb.mul_out[i].inst_info;
                rob_entry_in[N_ALU + i].rob.commit = 1'b1;
                bitmask[N_ALU + i] = 1'b1; 
            end
            // to fix lint warnings
            else begin
                rob_id_reg_select[N_ALU + i] = 'x;
                rob_entry_in[N_ALU + i] = 'x;
                bitmask[N_ALU + i] = 1'b0;
            end
        end
    end

    always_comb begin
        pop_from_rob = '1;
        // Dispatch:
        for(int unsigned i = 0; i < SS; i++)begin
            // setting up to read the first SS entries in the rob
            //inspect_queue[i].rob.commit = cdb[i].inst_info.reservation_entry.rob.commit;
            pop_from_rob &= inspect_queue[i].rob.commit && !rob_empty; //pop from queue if instr at the head is ready to commit
            rob_id_next[i] = head + ($clog2(ROB_DEPTH)-1)'(i);
            rob_id_out[i] = tail + ($clog2(ROB_DEPTH)-1)'(i);
        end
    end

    // Read eldest SS amount of instructions from queue
    // Determine whether any are ready to be committed 
    // Build a array of structs of size SS of what you would like to commit

  
    // counting order when we commit 
    logic [63:0] order_counter;
    // logic internal_prev_flush;
    logic valid_commit [SS];
    always_comb begin
        for(int i = 0; i < SS; i++) begin
            if(pop_from_rob) begin
                rob_entries_to_commit[i] = inspect_queue[i];
                // based on whether the i'th instruction is valid or not AND
                // whether a previous instruction was a mispredict or not, set valid
                rob_entries_to_commit[i].rvfi.valid = valid_commit[i]; 

                if(inspect_queue[i].inst.is_branch) begin
                    rob_entries_to_commit[i].rvfi.pc_wdata = inspect_queue[i].rob.fu_value; 
                end

                rob_entries_to_commit[i].rvfi.order = order_counter + {32'b0, i};
                // Send some signal to tell rrat to commit above entries
            end
            else begin
                rob_entries_to_commit[i] = 'x;
                rob_entries_to_commit[i].rvfi.valid = 1'b0;
            end
        end
    end

    // take the previous entry's mispredict bit and the current mispredict bit

    always_comb begin
        valid_commit[0] = inspect_queue[0].rob.commit; 
        // comb loops r dum
        flush = inspect_queue[0].rob.mispredict;

        for(int i = 1; i < SS; i++) begin
            flush = flush | inspect_queue[i].rob.mispredict;
            if(flush || ~inspect_queue[i].rob.commit) 
                valid_commit[i] = '0; 
            else 
                valid_commit[i] = '1; 
        end
    end
        
    always_ff @(posedge clk) begin
        if(rst || flush)
           order_counter <= 64'b0; 
        else if(pop_from_rob) begin
            // Set order on rvfi struct and commit to rrat (checking the tail)
            for(int i = 0; i < SS; i++) begin
                if(valid_commit[i])
                    order_counter <= order_counter + 1'd1;
            end
        end
    end
    
    endmodule : rob
