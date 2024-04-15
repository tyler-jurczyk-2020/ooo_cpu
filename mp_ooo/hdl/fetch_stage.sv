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
        output logic [31:0] imem_addr
    );

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
        end
        // if the instructon queue is NOT stalling b/c inst. queue & res. table are NOT full, and we're not waiting on instruction memory
        else if((~stall_inst && imem_resp)) begin
            // If our committed ROB is a branch and we are supposed to branch, then update to the new PC
            // else, pc goes up by 4

            // JANK 
            for(int i = 0; i < SS; i++) begin
                // if an input from the rob_entries_to_commit says to branch somewhere, start fetching from there
                // else, if the branch predictor says to branch, start fetching from the pc_next provided by decode
                // else, start fetching from pc + 4
            
                pc_reg <= pc_reg + 4;
                if(rob_entries_to_commit[i].rob.branch_enable && rob_entries_to_commit[i].rob.commit) begin
                    pc_reg <= rob_entries_to_commit[i].rvfi.pc_wdata; 
                    branch <= '1; 
                    break;
                end
            end

            if(~branch) begin
                for(int i = 0; i < SS; i++) begin
                    if(decoded_inst[i].is_branch && predict_branch) begin
                        pc_reg <= decoded_inst[i].pc_next; 
                        take_branch <= '1; 
                    end
                end
            end

            if(~take_branch) begin
                pc_reg <= pc_reg + 32'd4; 
            end

        end


    end

// U-DADDY
    endmodule : fetch_stage
