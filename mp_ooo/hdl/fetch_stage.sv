module fetch_stage
    import rv32i_types::*;
    (   
        input logic clk, 
        input logic rst,
        // For future branch predictor, if 0, then assume next inst is consecutive one
        input logic predict_branch, 
        // If for any reason we have to stall feeding the instruction queue
        input logic stall_inst,
        input logic imem_resp, 
        // Our new PC if we have to branch 
        input logic [31:0] branch_pc,
        // PC to fetch
        output logic [31:0] pc_reg
    );
    
    logic reset_hack;

    always_ff @(posedge clk) begin
        if(rst)
            reset_hack <= 1'b1;
        else
            reset_hack <= 1'b0;
    end


    always_ff @ (posedge clk) begin
        if(rst) begin
            pc_reg <= 32'h60000000;
        end
        // if you are not stalling
        else if((~stall_inst && imem_resp) || reset_hack) begin
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

    endmodule : fetch_stage
