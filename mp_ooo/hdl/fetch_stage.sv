module fetch_stage
    import rv32i_types::*;
    #(parameter SS = 2)
    (   
        input logic clk, 
        input logic rst,
        // For future branch predictor, if 0, then assume next inst is consecutive one
        input logic predict_branch, 
        // If for any reason we have to stall feeding the instruction queue
        input logic stall_inst,
        input logic imem_resp, 
        // Our new PC if we have to branch 
        input super_dispatch_t rob_entries_to_commit[SS],
        input instruction_info_reg_t decoded_inst [SS], 
        // PC to fetch
        output logic [31:0] pc_reg,
        output logic imem_rmask,
        output logic [31:0] imem_addr, 
        input logic valid_request, 
        input super_dispatch_t rob_entries_to_commit1[SS]
    );


    // If there's a flush, update reg to flush
    // If there is a imem_resp and reg_flush is high, then your instruction is invalid
    // If there's a imem_resp and reg_flush is low, then your instruction is valid
    // If there's a imem_resp, then set the flush signal to low

    assign imem_rmask = 1'b1;
    assign imem_addr = pc_reg;
    
    logic reset_hack;

    always_ff @(posedge clk) begin
        if(rst)
            reset_hack <= 1'b1;
        else
            reset_hack <= 1'b0;
    end

    logic [31:0] new_pc;

    logic branch; 
    logic take_branch; 
    always_ff @ (posedge clk) begin
        if(rst) begin
            pc_reg <= 32'h60000000;
            // valid_request <= '1; 
        end
        // else if (flush) begin
        //     valid_request <= '0; 
        // end
        // if the instructon queue is NOT stalling b/c inst. queue & res. table are NOT full, and we're not waiting on instruction memory
        else if((~stall_inst && imem_resp)) begin
            // valid_request <= '1; 

            // If our committed ROB is a branch and we are supposed to branch, then update to the new PC
            // else, pc goes up by 4
            // if(flush) begin
            //     valid_request <= '0; 
            // end

            // BEWARE: THE BRANCH AND THE TAKE_BRANCH LOGIC DOES NOT WORK. I REPEAT, WILL NOT WORK. 
            // WHEN YOU IMPLEMENT THE BRANCH PREDICTOR, THIS LOGIC MUST ALL BE CHANGED. THE ONLY REASON THIS WORKS IS BECAUSE THERE'S NO BRANCH PREDICTOR
            // JANK 
            for(int i = 0; i < SS; i++) begin
                // if an input from the rob_entries_to_commit says to branch somewhere, start fetching from there
                // else, if the branch predictor says to branch, start fetching from the pc_next provided by decode
                // else, start fetching from pc + 4
            
                pc_reg <= pc_reg + 4;
                if(valid_request) begin
                    if(rob_entries_to_commit[i].rob.branch_enable && rob_entries_to_commit[i].rob.commit) begin
                        pc_reg <= rob_entries_to_commit[i].rvfi.pc_wdata; 
                        branch <= '1; 
                        // pc_updated = '1; 
                        break;
                    end
                end
                else begin
                    if(rob_entries_to_commit1[i].rob.branch_enable && rob_entries_to_commit1[i].rob.commit) begin
                        pc_reg <= rob_entries_to_commit1[i].rvfi.pc_wdata; 
                        branch <= '1; 
                        // pc_updated = '1; 
                        break;
                    end
                end
            end

            if(~branch) begin
                for(int i = 0; i < SS; i++) begin
                    if(decoded_inst[i].is_branch && predict_branch) begin
                        pc_reg <= decoded_inst[i].pc_next; 
                        take_branch <= '1; 
                        // pc_updated <= '1; 
                        break; 
                    end
                end
                
            end

            if(~take_branch) begin
                pc_reg <= pc_reg + 32'd4; 
                // pc_updated <= '1; 
            end

            // valid_request <= pc_updated; 

        end


    end

// U-DADDY
    endmodule : fetch_stage
