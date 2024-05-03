module fu_wrapper_divide
    import rv32i_types::*;
    #(
        parameter sign = 0
    )
    (
        input logic clk, rst,
        // get entry from reservation station
        input fu_input_t to_be_divided, 
        
        // Handshaking logic to state whether a multiplier is available
        output logic FU_ready, 

        // Write out results
        output fu_output_t div_output,

        // Register values for instruction to be multiplied
        input physical_reg_response_t fu_reg_data
    );

    divide_FUs_t division; 
    logic div_available;
    logic complete_one_cycle; 
    fu_output_t div_output_test;

    logic [31:0] quotient; 
    logic [31:0] remainder; 
    logic divide_by_0;
    logic complete; 

    logic prog_start; 

    always_ff @ (posedge clk) begin
        if(rst) begin
            division <= '0; 
            prog_start <= '0; 
        end
        else if(to_be_divided.start_calculate) begin
            prog_start <= '1; 
            division.inst_info <= to_be_divided.inst_info;             
            division.a <= fu_reg_data.rs1_v.register_value; 
            division.b <= fu_reg_data.rs2_v.register_value; 
            if(to_be_divided.inst_info.inst.div_type == 2'd0 || to_be_divided.inst_info.inst.div_type == 2'd1) begin
                division.what_we_want <= '1; 
            end
            else begin
                division.what_we_want <= '0; 
            end
        end
    end

    always_ff @ (posedge clk) begin
        if(rst) begin
            div_available <= '1; 
        end
        else begin
            if(to_be_divided.start_calculate) begin
                div_available <= '0; 
            end
            else if(complete) begin
                div_available <= '1; 
            end
        end
    end

    always_comb begin
        FU_ready = '0; 
        FU_ready |= div_available;
        // Black magic
        FU_ready &= ~to_be_divided.start_calculate;
    end

    // unsigned version
    DW_div_seq #(.a_width(32), .b_width(32), .tc_mode(sign), .num_cyc(20), .rst_mode(0), 
    .input_mode(1), .output_mode(0), .early_start(0)) fuck_du (
        .clk(clk), .rst_n(~rst), 
        .hold('0), 
        .start(to_be_divided.start_calculate),
        .a(fu_reg_data.rs1_v.register_value), 
        .b(fu_reg_data.rs2_v.register_value), 
        .quotient(quotient), 
        .remainder(remainder), 
        .divide_by_0(divide_by_0), 
        .complete(complete)); 

    always_comb begin
        div_output_test = '0; 
        if(complete && prog_start) begin
            div_output_test.inst_info = division.inst_info;
            div_output_test.ready_for_writeback = 1'b1;
            div_output_test.inst_info.rvfi.rs1_rdata = division.a;
            div_output_test.inst_info.rvfi.rs2_rdata = division.b;
            if(division.what_we_want) begin
                div_output_test.register_value = quotient;
                div_output_test.inst_info.rvfi.rd_wdata = quotient;
            end
            else begin
                div_output_test.register_value = remainder;
                div_output_test.inst_info.rvfi.rd_wdata = remainder;
            end
        end
    end    

    // always_ff @ (posedge clk) begin
    //     if(rst) begin
    //         div_output_test <= '0; 
    //     end
    //     else begin
    //         if(complete_one_cycle) begin
    //             div_output_test <= div_output_test; 
    //         end
    //         else begin
    //             div_output_test <= '0; 
    //         end
    //     end
    // end

    always_comb begin
        div_output = '0; 
        if(complete_one_cycle) begin
            div_output = div_output_test; 
        end
    end

    logic last_complete; 
    // Reset or capture the complete signal for one cycle
    always_ff @(posedge clk) begin
        if (rst) begin
            complete_one_cycle <= '0;
            last_complete <= '0; 
        end else begin
            last_complete <= complete; 
            if (complete && !last_complete) begin
                complete_one_cycle <= '1;
            end else begin
                complete_one_cycle <= '0;
            end
        end
    end
    
    
endmodule : fu_wrapper_divide
