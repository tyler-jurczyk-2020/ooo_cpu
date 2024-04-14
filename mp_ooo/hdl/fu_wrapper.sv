module fu_wrapper
    import rv32i_types::*;
    (
        input logic clk, // rst,
        // get entry from reservation station
        input fu_input_t to_be_calculated, 

        output fu_output_t alu_cmp_output,
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

    logic [31:0] alu_input_a; 
    logic [31:0] alu_input_b; 
    logic [31:0] cmp_input_a; 
    logic [31:0] cmp_input_b; 

    logic [31:0] alu_res;
    logic cmp_res;

    // Need to properly extend to superscalar
    always_comb begin
        unique case (to_be_calculated.inst_info.inst.execute_operand1)
            2'b00 : alu_input_a = fu_reg_data.rs1_v.register_value;
            2'b01 : alu_input_a = to_be_calculated.inst_info.inst.immediate; 
            2'b11 : alu_input_a = to_be_calculated.inst_info.inst.pc_curr;
            default : alu_input_a = 'x;
        endcase
        unique case (to_be_calculated.inst_info.inst.execute_operand2)
            2'b00 : alu_input_b = fu_reg_data.rs2_v.register_value;
            2'b01 : alu_input_b = '0;
            2'b11 : alu_input_b = to_be_calculated.inst_info.inst.immediate;
            default : alu_input_b = 'x;
        endcase
    end

    
    always_comb begin
        cmp_input_a = alu_input_a;
        cmp_input_b = alu_input_b;

        if(to_be_calculated.inst_info.inst.is_branch) begin
            cmp_input_a = fu_reg_data.rs1_v.register_value;
            cmp_input_b = fu_reg_data.rs2_v.register_value;
        end
    end
        
    

    alu calculator(.aluop(to_be_calculated.inst_info.inst.alu_operation), 
                    .a(alu_input_a),
                    .b(alu_input_b),
                    .f(alu_res));
    
    cmp comparator(.cmpop(to_be_calculated.inst_info.inst.cmp_operation), 
                    .a(cmp_input_a),
                    .b(cmp_input_b),
                    .br_en(cmp_res));
    

    // Select register to push out
    always_ff @(posedge clk) begin
        alu_cmp_output.inst_info <= to_be_calculated.inst_info;

        if(to_be_calculated.inst_info.inst.is_branch) begin
            alu_cmp_output.inst_info.rvfi.rd_wdata  <= '0;
            alu_cmp_output.register_value <= alu_res;
        end
        else if(~to_be_calculated.inst_info.inst.alu_en) begin
            alu_cmp_output.inst_info.rvfi.rd_wdata  <= {31'd0, cmp_res};
            alu_cmp_output.register_value <= {31'd0, cmp_res};
        end 
        else begin
            alu_cmp_output.inst_info.rvfi.rd_wdata <= alu_res;
            alu_cmp_output.register_value <= alu_res;
        end

        alu_cmp_output.ready_for_writeback <= 1'b1;
        alu_cmp_output.branch_result <= cmp_res; 
        
        alu_cmp_output.inst_info.rvfi.rs1_rdata <= fu_reg_data.rs1_v.register_value;
        alu_cmp_output.inst_info.rvfi.rs2_rdata <= fu_reg_data.rs2_v.register_value;
    end
        
endmodule : fu_wrapper

