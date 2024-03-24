module fetch_stage
    import rv32i_types::*;
    (   
        input logic clk, 
        input logic rst,
        // For future branch predictor, if 0, then assume next inst is consecutive one
        input logic predict_branch, 
        // If for any reason we have to stall feeding the instruction queue
        input logic stall_inst,
        // Our new PC if we have to branch 
        input logic [31:0] branch_pc, 
        // PC to fetch
        output fetch_output_reg_t fetch_output
    );

    logic [31:0] pc_reg; 

    always_ff @ (posedge clk) begin
        if(rst) begin
            pc_reg <= 32b'h60000000;
        end
        // if you are not stalling
        if(~stall_inst) begin
            // if you are not branching
            if(~predict_branch) begin
                pc_reg <= pc_reg + 32'd4; 
            end
            // If you are branching 
            else begin
                pc_reg <= branch_pc; 
            end
        end            
    end

    assign fetch_output.fetch_pc_curr = pc_reg; 
    assign fetch_output.fetch_pc_next = pc_reg + 32'd4; 
    
    endmodule : fetch_stage