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
        input cdb_t cdb [SS],
    ////// OUTPUTS:
        // ROB line of comm to physical register file
        output physical_reg_request_t rob_request [SS],
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
    
    logic [$clog2(ROB_DEPTH)-1:0] rob_id_reg_select[SS][FU_COUNT];
    super_dispatch_t rob_entry_in[SS][FU_COUNT];
    logic [SS-1:0] bitmask[FU_COUNT], out_bitmask;
    // ROB receives data from cdb and updates commit flag in circular queue
    circular_queue #(.SS(SS), .QUEUE_TYPE(super_dispatch_t), .DEPTH(ROB_DEPTH), .DIM_SEL(FU_COUNT)) rob_dut(.clk(clk), .rst(rst), .in(dispatch_info), .push(avail_inst), .pop(pop_from_rob), 
    .reg_select_out(rob_id_out), 
    .reg_out(inspect_queue), .reg_select_in(rob_id_reg_select), .reg_in(rob_entry_in), .in_bitmask(bitmask), .out_bitmask(out_bitmask),// One hot bitmask
    .head_out(head), .tail_out(tail), .full(rob_full), .empty(rob_empty));


    always_comb begin
        for(int i = 0; i < SS; i++)begin
            for(int j = 0; j < FU_COUNT; j++) begin
                out_bitmask[i] = 1'b1;
                if(cdb[i][j].ready_for_writeback) begin
                    rob_id_reg_select[i][j] = cdb[i][j].inst_info.rob.rob_id[2:0]; // Need to fix
                    rob_entry_in[i][j] = cdb[i][j].inst_info;
                    rob_entry_in[i][j].rob.commit = 1'b1;
                    bitmask[j][i] = 1'b1; 
                end
                // to fix lint warnings
                else begin
                    rob_id_reg_select[i][j] = 'x;
                    rob_entry_in[i][j] = 'x;
                    bitmask[j][i] = 1'b0;
                end
            end
        end
    end

    always_comb begin
        pop_from_rob = '1;
        // Dispatch:
        for(int i = 0; i < SS; i++)begin
            // setting up to read the first SS entries in the rob
            //inspect_queue[i].rob.commit = cdb[i].inst_info.reservation_entry.rob.commit;
            pop_from_rob &= inspect_queue[i].rob.commit && !rob_empty; //pop from queue if instr at the head is ready to commit
            rob_id_next[i] = head + i[$clog2(ROB_DEPTH)-1:0];
            rob_id_out[i] = tail + i[$clog2(ROB_DEPTH)-1:0];

            // Check each ss slot if an instruction has been dispatched
            if (avail_inst)begin     
                // Regfile should be updated w/ new phys reg mapping
                rob_request[i].rd_en = 1'b1; 
                rob_request[i].rd_s = dispatch_info[i].rat.rd; // Need to get PR not ISA reg
                rob_request[i].rd_v.ROB_ID = rob_id_next[i];
            end
            else begin
                rob_request[i].rd_en = 1'b0;
                for(int i = 0; i < SS; i++) begin
                    rob_request[i].rd_s = 'x;
                    rob_request[i].rd_en = 1'b0;
                    rob_request[i].rd_v = 'x; 
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
            else begin
                rob_entries_to_commit[i] = 'x;
                rob_entries_to_commit[i].rvfi.valid = 1'b0;
            end
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
