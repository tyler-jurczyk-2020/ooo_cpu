module fetch_stage
    import rv32i_types::*;
    #(parameter SS = 2)
    (   
        input logic clk, 
        input logic rst,
        // If for any reason we have to stall feeding the instruction queue
        input logic stall_inst,
        input logic imem_resp, 
        // Our new PC if we have to branch 
        input super_dispatch_t rob_entries_to_commit[SS],
        input instruction_info_reg_t decoded_inst [SS], 
        // PC to fetch
        output logic [31:0] pc_reg [SS],
        output logic imem_rmask,
        output logic [31:0] imem_addr, 
        input logic valid_request, 
        input super_dispatch_t rob_entries_to_commit1[SS]
        // output logic valid_inst_exception
    );

    assign imem_rmask = 1'b1;
    assign imem_addr = pc_reg[0];
    
    logic reset_hack;

    logic valid_inst_exception; 

    always_ff @(posedge clk) begin
        if(rst)
            reset_hack <= 1'b1;
        else
            reset_hack <= 1'b0;
    end

    always_ff @ (posedge clk) begin
        if(rst) begin
            pc_reg[0] <= 32'h60000000;
            valid_inst_exception <= '0; 
            pc_reg[1] <= 32'h60000004;
        end
        // If we are not stalling and instruction memory is ready for a new instruction
        else if((~stall_inst && imem_resp)) begin
            // for(int i = 0; i < SS; i++) begin
                valid_inst_exception <= '0; 
                // Check last instruction committed to see whether we are to branch
                // valid_request is just a signal to see if a flush occured during an instruction request
            if(valid_request && rob_entries_to_commit[0].rob.mispredict && rob_entries_to_commit[0].rob.commit && (pc_reg[0] != rob_entries_to_commit[0].rvfi.pc_wdata)) begin
                pc_reg[0] <= rob_entries_to_commit[0].rvfi.pc_wdata; 
                pc_reg[1] <= rob_entries_to_commit[0].rvfi.pc_wdata + 32'd4; 
            end
            else if(~valid_request && rob_entries_to_commit1[0].rob.mispredict && rob_entries_to_commit1[0].rob.commit) begin
                pc_reg[0] <= rob_entries_to_commit1[0].rvfi.pc_wdata; 
                pc_reg[1] <= rob_entries_to_commit1[0].rvfi.pc_wdata + 32'd4; 
                valid_inst_exception <= '1; 
            end
            else if(valid_request && rob_entries_to_commit[1].rob.mispredict && rob_entries_to_commit[1].rob.commit && (pc_reg[0] != rob_entries_to_commit[1].rvfi.pc_wdata)) begin
                pc_reg[0] <= rob_entries_to_commit[1].rvfi.pc_wdata; 
                pc_reg[1] <= rob_entries_to_commit[1].rvfi.pc_wdata + 32'd4; 
            end
            else if(~valid_request && rob_entries_to_commit1[1].rob.mispredict && rob_entries_to_commit1[1].rob.commit) begin
                pc_reg[0] <= rob_entries_to_commit1[1].rvfi.pc_wdata; 
                pc_reg[1] <= rob_entries_to_commit1[1].rvfi.pc_wdata + 32'd4; 
                valid_inst_exception <= '1; 
            end
            // Check the decoded instructions to check for a JAL
            else if((decoded_inst[0].is_jump || (decoded_inst[0].is_branch && decoded_inst[0].predict_branch)) && (pc_reg[0] != decoded_inst[0].pc_next)) begin
                pc_reg[0] <= decoded_inst[0].pc_next;  
                pc_reg[1] <= decoded_inst[0].pc_next + 32'd4; 
            end
            else if((decoded_inst[1].is_jump || (decoded_inst[1].is_branch && decoded_inst[1].predict_branch)) && (pc_reg[0] != decoded_inst[1].pc_next)) begin
                pc_reg[0] <= decoded_inst[1].pc_next;  
                pc_reg[1] <= decoded_inst[1].pc_next + 32'd4; 
            end
            else if(decoded_inst[0].bad_but_pop_rob_anyway) begin
                pc_reg[0] <= decoded_inst[0].pc_curr;  
                pc_reg[1] <= decoded_inst[0].pc_curr + 32'd4; 
            end
            else if(decoded_inst[1].bad_but_pop_rob_anyway) begin
                pc_reg[0] <= decoded_inst[1].pc_curr;  
                pc_reg[1] <= decoded_inst[1].pc_curr + 32'd4; 
            end
            // Else just increment by two
            else begin
                pc_reg[0] <= pc_reg[0] + 32'd8; 
                pc_reg[1] <= pc_reg[1] + 32'd8; 
            end
        end
    end


// U-DADDY
    endmodule : fetch_stage