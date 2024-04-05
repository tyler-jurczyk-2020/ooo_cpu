module fu_wrapper_mult
    import rv32i_types::*;
    #(
        parameter SS = 2,
        parameter reservation_table_size = 8
    )
    (
        input logic clk, rst,
        // get entry from reservation station
        input fu_input_t to_be_multiplied, 

        // Handshaking logic to state whether a multiplier is available
        output logic FU_ready, 

        // Write out results
        output cdb_t cdb [SS],

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

    logic mult_status [SS]; 
    logic mul_available [SS];
    logic [63:0] mult_output [SS];

    multiply_FUs_t multiplication [SS]; 

    always_ff @ (posedge clk) begin
        for(int i = 0; i < SS; i++) begin
            if(to_be_multiplied.start_calculate) begin
                multiplication[i].start <= '1; 
                multiplication[i].mul_type <= to_be_multiplied.inst_info.inst.mul_type; 
                multiplication[i].a <= fu_reg_data.rs1_v; 
                multiplication[i].b <= fu_reg_data.rs2_v; 
                break; 
            end
        end
    end

    always_ff @ (posedge clk) begin
        for(int i = 0; i < SS; i++) begin
            if(rst) begin
                mul_available[i] <= '0; 
            end
            else begin
                if(to_be_multiplied.start_calculate) begin
                    mul_available[i] <= '0; 
                end
                else if(mult_status[i]) begin
                    mul_available[i] <= '1; 
                end
            end
        end
    end



    always_comb begin
        FU_ready = '0; 
        for(int i = 0; i < SS; i++) begin
            FU_ready |= mul_available[i];
        end
    end

    generate 
        for(genvar i = 0; i < SS; i++) begin: MULTs
            shift_add_multiplier shi(.clk(clk), 
                                 .rst(rst), 
                                 .start(multiplication[i].start), 
                                 .mul_type(multiplication[i].mul_type), 
                                 .a(multiplication[i].a), 
                                 .b(multiplication[i].b), 
                                 .p(mult_output[i]), 
                                 .done(mult_status[i]));
        end
    endgenerate   

    always_comb begin
        for(int i = 0; i < SS; i++) begin
            if(mult_status[i]) begin
                cdb[i][MUL].inst_info = to_be_multiplied.inst_info;
                cdb[i][MUL].register_value = mult_output[i];
                cdb[i][MUL].ready_for_writeback = 1'b1;
                cdb[i][MUL].inst_info.rvfi.rd_wdata = mult_output[i];
            end
        end
    end

endmodule : fu_wrapper_mult
    