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
        output logic pop_from_rob, 
        output super_dispatch_t rob_entries_to_commit1 [SS],
        // Inform LSQ when to commit a store
        output logic commit_store
    );
    
    // head & tail pointers for ROB entries
    logic [$clog2(ROB_DEPTH)-1:0] head, tail;
    logic push_to_rob;
    super_dispatch_t inspect_queue [SS];
    logic rob_empty;

    logic [$clog2(ROB_DEPTH)-1:0] rob_id_out[SS];
    
    logic [$clog2(ROB_DEPTH)-1:0] rob_id_reg_select [CDB];
    super_dispatch_t rob_entry_in [CDB];
    logic [(CDB)-1:0] bitmask;

    logic push_dispatch_entry; // Should not push invalidated instructions
    
    assign push_dispatch_entry = avail_inst && dispatch_info[0].rvfi.valid;
    // ROB receives data from cdb and updates commit flag in circular queue
    circular_queue #(.SS(SS), .SEL_IN(CDB), .SEL_OUT(SS), .QUEUE_TYPE(super_dispatch_t), .DEPTH(ROB_DEPTH)) rob_dut(.clk(clk), .rst(rst || flush), .in(dispatch_info), .push(push_dispatch_entry), .pop(pop_from_rob), 
    .reg_select_out(rob_id_out),
    .reg_out(inspect_queue), .reg_select_in(rob_id_reg_select), .reg_in(rob_entry_in), .in_bitmask(bitmask), .out_bitmask('1),// One hot bitmask
    .head_out(head), .tail_out(tail), .full(rob_full), .empty(rob_empty));

    always_comb begin
        for(int i = 0; i < CDB; i++) begin
            rob_id_reg_select[i] = 'x;
            rob_entry_in[i] = 'x;
            bitmask[i] = 1'b0;
            if(cdb[i].ready_for_writeback) begin
                rob_id_reg_select[i] = cdb[i].inst_info.rob.rob_id; // Need to fix
                rob_entry_in[i] = cdb[i].inst_info;
                rob_entry_in[i].rob.commit = 1'b1;
                bitmask[i] = 1'b1; 

                //rob_entry_in[i].rob.fu_value = cdb[i].register_value;
                if((cdb[i].inst_info.inst.is_branch || cdb[i].inst_info.inst.is_jump || cdb[i].inst_info.inst.is_jumpr)
                 && cdb[i].branch_result) begin
                    rob_entry_in[i].rob.branch_enable = '1; 
                end
                else begin
                    rob_entry_in[i].rob.branch_enable = '0; 
                end

                if((cdb[i].inst_info.inst.is_branch && (cdb[i].branch_result ^ cdb[i].inst_info.inst.predict_branch)) || cdb[i].inst_info.inst.is_jumpr) begin
                    rob_entry_in[i].rob.mispredict = '1;
                end
                else begin
                    rob_entry_in[i].rob.mispredict = '0;
                end
            end
        end
    end

    // Inform lsq when to commit a store
    always_comb begin
        commit_store = 1'b0;
        for(int i = 0; i < SS; i++) begin
            if(inspect_queue[i].inst.opcode == op_b_store && !rob_entries_to_commit[i].rvfi.valid)
                commit_store |= 1'b1;
            else if(inspect_queue[i].inst.opcode == op_b_store && rob_entries_to_commit[i].rvfi.valid
                   && rob_entries_to_commit[i].rvfi.order != inspect_queue[i].rvfi.order)
                    commit_store |= 1'b1;
        end
    end

    // always_comb begin
    //     // if(inspect_queue[0].rob.mispredict) begin
    //     //     pop_from_rob = inspect_queue[0].rob.commit && !rob_empty;
    //     // end
    //     // else begin
    //     //     pop_from_rob = '1;
    //     // //     // Dispatch:
    //     //     for(int unsigned i = 0; i < SS; i++)begin
    //     //         // setting up to read the first SS entries in the rob
    //     //         //inspect_queue[i].rob.commit = cdb[i].inst_info.reservation_entry.rob.commit;
    //     //         pop_from_rob &= inspect_queue[i].rob.commit && !rob_empty; //pop from queue if instr at the head is ready to commit
    //     //         rob_id_next[i] = head + ($clog2(ROB_DEPTH)-1)'(i);
    //     //         rob_id_out[i] = tail + ($clog2(ROB_DEPTH)-1)'(i);
    //     //     end
    //     // end
    //     for(int unsigned i = 0; i < SS; i++)begin
    //         // setting up to read the first SS entries in the rob
    //         //inspect_queue[i].rob.commit = cdb[i].inst_info.reservation_entry.rob.commit;
    //         pop_from_rob &= inspect_queue[i].rob.commit && !rob_empty; //pop from queue if instr at the head is ready to commit
    //         rob_id_next[i] = head + ($clog2(ROB_DEPTH)-1)'(i);
    //         rob_id_out[i] = tail + ($clog2(ROB_DEPTH)-1)'(i);
    //     end
    // end
    always_comb begin
        // pop_from_rob = '1;

        if(inspect_queue[0].rob.commit && inspect_queue[0].rob.mispredict && !rob_empty) begin
            pop_from_rob = '1; 
        end
        else if(inspect_queue[0].rob.commit && inspect_queue[1].rob.commit && !rob_empty) begin
            pop_from_rob = '1; 
        end
        else begin
            pop_from_rob = '0; 
        end

        // Dispatch:
        for(int unsigned i = 0; i < SS; i++)begin
            // setting up to read the first SS entries in the rob
            //inspect_queue[i].rob.commit = cdb[i].inst_info.reservation_entry.rob.commit;
            // pop_from_rob &= inspect_queue[i].rob.commit && !rob_empty; //pop from queue if instr at the head is ready to commit
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
                rob_entries_to_commit[i].rvfi.pc_wdata = inspect_queue[i].inst.pc_next;
                rob_entries_to_commit[i].rvfi.order = order_counter + {32'b0, i};
                // Send some signal to tell rrat to commit above entries
            end
            else begin
                rob_entries_to_commit[i] = 'x;
                rob_entries_to_commit[i].rvfi.valid = 1'b0;
            end
        end
    end



    always_ff @ (posedge clk) begin
        if(pop_from_rob) begin
            rob_entries_to_commit1 <= rob_entries_to_commit;
        end
    end

    // take the previous entry's mispredict bit and the current mispredict bit'
    
    // Set a valid_commit signal, so that when rob pops, only the valid signals are popped
    // this valid signal will also drive the order signal 

    // if first way is a mispredicted branch (we need to flush pipeline & second way)
    // if second way is a mispredicted branch (we need to flush pipeline, but not either of the ways to be committed)

    // if there's a mispredict on the first branch, we are committing and thus should flush
    // if there's a mispredict on the second branch, we are committing and thus should flush 
    // if at least the first instruction is ready to be committed and is a mispredict, we should flush


    always_comb begin
        valid_commit[0] = inspect_queue[0].rob.commit; 
        // the first way will always have a valid commit
        // if the second way is to incurr a flush, we need the second way to be valid for commit and the first way to be valid for commit
        // writing the logic like this allows you to 

        // you flush due to the first way if the first way has a mispredict and is a valid instruction 
        // you flush due to the second way if the second way isn't a bad instruction, and is a valid instruction, and has a mispredict

        // an instruction in the first way is valid if it exists
        // an instruction in the second way is valid if it exists, its not a bad instruction, and the first instruction isn't a branch, jump, or jumpr

        if(inspect_queue[0].rob.commit && inspect_queue[1].rob.commit && !(inspect_queue[0].inst.is_branch || inspect_queue[0].inst.is_jump || inspect_queue[0].inst.is_jumpr) && ~inspect_queue[1].inst.bad_but_pop_rob_anyway) begin
            valid_commit[1] = '1; 
        end
        else begin
            valid_commit[1] = '0; 
        end

        flush = (inspect_queue[0].rob.commit && inspect_queue[0].rob.mispredict) || (valid_commit[1] && inspect_queue[1].rob.mispredict);


        // if(inspect_queue[0].rob.commit) begin
        //     flush = (valid_commit[0] && inspect_queue[0].rob.mispredict) || (valid_commit[1] && inspect_queue[1].rob.mispredict); 
        // end
        // else begin
        //     flush = '0; 
        // end

        // if(~inspect_queue[1].rob.commit || (inspect_queue[0].inst.is_branch || inspect_queue[0].inst.is_jump || inspect_queue[0].inst.is_jumpr)) begin
        //     valid_commit[1] = '0; 
        // end
        // else begin
        //     valid_commit[1] = inspect_queue[1].rob.commit && ~inspect_queue[1].inst.bad_but_pop_rob_anyway; 
        // end

    end
    
    logic [63:0] counter; 
    always_comb begin
        counter = order_counter; 
        if(pop_from_rob) begin
            // Set order on rvfi struct and commit to rrat (checking the tail)
            for(int i = 0; i < SS; i++) begin
                if(valid_commit[i])
                    counter = counter + 1'd1;
            end
        end
    end

    always_ff @(posedge clk) begin
        if(rst)
           order_counter <= 64'b0; 
        else if(pop_from_rob) begin
            // Set order on rvfi struct and commit to rrat (checking the tail)
            order_counter <= counter; 
        end
    end
    
    endmodule : rob
