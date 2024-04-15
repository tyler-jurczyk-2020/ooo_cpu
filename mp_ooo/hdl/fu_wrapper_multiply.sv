module fu_wrapper_mult
    import rv32i_types::*;
    (
        input logic clk, rst,
        // get entry from reservation station
        input fu_input_t to_be_multiplied, 
        
        // Handshaking logic to state whether a multiplier is available
        output logic FU_ready, 

        // Write out results
        output fu_output_t mul_output,

        // Register values for instruction to be multiplied
        input physical_reg_response_t fu_reg_data
    );
    // the reservation 
    // hi guys
    // ben bitdiddle is who I aspire to be

    // Need to implement N-way number of alu & multiply FUs 
    // Need a way to inform the reservation station that the calculation is finished

    // TYPE | OP | (RS1, RS2) NEEDED | (Operand1, Operand2) is immediate or PC
    // U-Type: neither (umm + 0) (No, No) (Yes, Yes)
    // R-Type: R1 + R2 (Yes, Yes) (No, No)
    // I-Type: R1 + imm (Yes, No) (No, Yes)
    // S-type: R1 + smm => [R2] (Yes, Yes) (No, Yes)
    // B-Type: CMP R1 & R2, ALU PC + bmm (Yes, Yes) (Yes, Yes)
    // J-type: neither PC + 4, PC + jmm (No, No) (Yes, Yes) 

    logic mult_status; 
    logic mul_available;
    logic [63:0] mult_output;

    multiply_FUs_t multiplication; 

    always_ff @ (posedge clk) begin
        if(to_be_multiplied.start_calculate) begin
            multiplication.start <= '1; 
            multiplication.mul_type <= to_be_multiplied.inst_info.inst.mul_type; 
            multiplication.a <= fu_reg_data.rs1_v.register_value; 
            multiplication.b <= fu_reg_data.rs2_v.register_value; 
            multiplication.inst_info <= to_be_multiplied.inst_info; 
        end
        else if(mult_status)
            multiplication.start <= '0;
    end

    always_ff @ (posedge clk) begin
        if(rst) begin
            mul_available <= '1; 
        end
        else begin
            if(to_be_multiplied.start_calculate) begin
                mul_available <= '0; 
            end
            else if(mult_status) begin
                mul_available <= '1; 
            end
        end
    end

    always_comb begin
        FU_ready = '0; 
        FU_ready |= mul_available;
        // Black magic
        FU_ready &= ~to_be_multiplied.start_calculate;
    end

    shift_add_multiplier shi(.clk(clk), 
                            .rst(rst), 
                            .start(multiplication.start), 
                            .mul_type(multiplication.mul_type), 
                            .a(multiplication.a), 
                            .b(multiplication.b), 
                            .p(mult_output), 
                            .done(mult_status));

    always_comb begin
        mul_output = '0;
        if(mult_status) begin
            mul_output.inst_info = multiplication.inst_info;
            mul_output.register_value = mult_output;
            mul_output.ready_for_writeback = 1'b1;
            mul_output.inst_info.rvfi.rd_wdata = mult_output;
            mul_output.inst_info.rvfi.rs1_rdata = multiplication.a;
            mul_output.inst_info.rvfi.rs2_rdata = multiplication.b;
        end
    end
endmodule : fu_wrapper_mult
