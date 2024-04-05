module fu_wrapper
    import rv32i_types::*;
    #(
        parameter SS = 2,
        parameter reservation_table_size = 8,
        parameter ROB_DEPTH = 7,
        parameter FU_COUNT = SS
    )
    (
        input logic clk, rst,
        // get entry from reservation station
        input fu_input_t to_be_calculated, 

        output cdb_t cdb [SS],
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

    logic [31:0] alu_input_a [SS]; 
    logic [31:0] alu_input_b [SS]; 
    logic [31:0] cmp_input_a [SS]; 
    logic [31:0] cmp_input_b [SS]; 

    // Need to properly extend to superscalar
    always_comb begin
        for(int i = 0; i < SS; i++) begin
            unique case (to_be_calculated.inst_info.inst.execute_operand1)
                2'b00 : alu_input_a[i] = fu_reg_data.rs1_v.register_value;
                2'b01 : alu_input_a[i] = to_be_calculated.inst_info.inst.immediate; 
                2'b11 : alu_input_a[i] = to_be_calculated.inst_info.inst.pc_curr;
                default : alu_input_a[i] = 'x;
            endcase
            unique case (to_be_calculated.inst_info.inst.execute_operand2)
                2'b00 : alu_input_b[i] = fu_reg_data.rs2_v.register_value;
                2'b01 : alu_input_b[i] = '0;
                2'b11 : alu_input_b[i] = to_be_calculated.inst_info.inst.immediate;
                default : alu_input_b[i] = 'x;
            endcase
        end
    end

    always_comb begin
        for(int i = 0; i < SS; i++) begin
            cmp_input_a[i] = alu_input_a[i]; 
            cmp_input_b[i] = alu_input_b[i]; 
            // if(to_be_calculated[i].inst_info.inst.is_branch) begin
                cmp_input_a[i] = fu_reg_data.rs1_v.register_value; 
                cmp_input_b[i] = fu_reg_data.rs2_v.register_value; 
            // end
        end
    end

    logic [31:0] alu_output [SS]; 
    logic cmp_output [SS]; 

    generate 
        for(genvar i = 0; i < SS; i++) begin: FUs
            alu calculator(.aluop(to_be_calculated.inst_info.inst.alu_operation), 
                           .a(alu_input_a[i]), 
                           .b(alu_input_b[i]), 
                           .f(alu_output[i])); 
            cmp comparator(.cmpop(to_be_calculated.inst_info.inst.cmp_operation), 
                           .a(cmp_input_a[i]), 
                           .b(cmp_input_b[i]), 
                           .br_en(cmp_output[i])); 
        end
    endgenerate   

        
    // Select register to push out
    always_comb begin
        for(int i = 0; i < SS; i++) begin
            // Always drive alu out since it only takes one clock cycle
            cdb[i][ALU].inst_info = to_be_calculated.inst_info;
            cdb[i][ALU].register_value = alu_output[i];
            cdb[i][ALU].ready_for_writeback = 1'b1;
            cdb[i][ALU].inst_info.rvfi.rd_wdata = alu_output[i];
            cdb[i][ALU].inst_info.rvfi.rs1_rdata = fu_reg_data.rs1_v.register_value;
            cdb[i][ALU].inst_info.rvfi.rs2_rdata = fu_reg_data.rs2_v.register_value;
        end
    end
        
endmodule : fu_wrapper
    