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
    logic make_for_one_cycle; 

    logic [31:0] quotient; 
    logic [31:0] remainder; 
    logic divide_by_0;
    logic complete; 

    always_ff @ (posedge clk) begin
        if(rst) begin
            division <= '0; 
        end
        else if(to_be_divided.start_calculate) begin
            division.inst_info <= to_be_divided.inst_info;             
            division.a <= fu_reg_data.rs1_v.register_value; 
            division.b <= fu_reg_data.rs2_v.register_value; 
            if(to_be_divided.inst_info.inst.div_type == 2'd0 || to_be_divided.inst_info.inst.div_type == 2'd1) begin
                division.what_we_want = '0; 
            end
            else begin
                division.what_we_want = '1; 
            end
        end
    end

    always_ff @ (posedge clk) begin
        if(rst) begin
            div_available <= '1; 
        end
        else begin
            if(to_be_multiplied.start_calculate) begin
                div_available <= '0; 
            end
            else if(mult_status) begin
                div_available <= '1; 
            end
        end
    end

    always_comb begin
        FU_ready = '0; 
        FU_ready |= div_available;
        // Black magic
        FU_ready &= ~to_be_multiplied.start_calculate;
    end

    // unsigned version
    DW_div_seq #(.a_width(32), .b_width(32), tc_mode(sign), .num_c(10), .rst_mode(0), 
    .input_mode(1), .output_mode(0), .early_start(0)) fuck_du (
        .clk(clk), .rst_n(~rst), 
        .hold('0), 
        .start(to_be_divided.start_calculate)
        .a(fu_reg_data.rs1_v.register_value), 
        .b(fu_reg_data.rs2_v.register_value), 
        .quotient(quotient), 
        .remainder(remainder), 
        .divide_by_0(divide_by_0), 
        .complete(complete)); 

    always_comb begin
        div_output = '0; 
        if(complete) begin
            div_output.inst_info = division.inst_info;
            div_output.ready_for_writeback = 1'b1;
            div_output.inst_info.rvfi.rs1_rdata = division.a;
            div_output.inst_info.rvfi.rs2_rdata = division.b;
            if(division.what_we_want) begin
                div_output.register_value = quotient;
                div_output.inst_info.rvfi.rd_wdata = quotient;
            end
            else begin
                div_output.register_value = remainder;
                div_output.inst_info.rvfi.rd_wdata = remainder;
            end
        end
    end    
    
endmodule : fu_wrapper_divide
