module fu_wrapper
    import rv32i_types::*;
    #(
        parameter SS = 2,
        parameter reservation_table_size = 8,
        parameter ROB_DEPTH = 8 
    )
    (
        input logic clk, rst,
        // get entry from reservation station
        input fu_input_t to_be_calculated [SS], 

        output logic alu_status, 
        output logic mult_status,

        output fu_output_t fu_output [SS], 

        output logic [$clog2(TABLE_ENTRIES)-1:0] rs1_s_dispatch_request [SS], 
        output logic [$clog2(TABLE_ENTRIES)-1:0] rs2_s_dispatch_request [SS], 
        input  physical_reg_data_t source_reg_1 [SS], source_reg_2 [SS]

    );
    // my favorite rapper is the diddler
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

    // Incorrect, need to get corrected value
    logic op1_is_imm;
    logic op2_is_imm;
    assign op1_is_imm = 1'b0;
    assign op2_is_imm = 1'b0;

    always_comb begin
        for(int i = 0; i < SS; i++) begin
            if(op1_is_imm && ~to_be_calculated[i].inst_info.reserevation_entry.inst.is_branch && ~to_be_calculated[i].inst_info.reserevation_entry.inst.is_jump) begin
                alu_input_a[i] = to_be_calculated[i].inst_info.reserevation_entry.inst.immediate; 
            end
            else if(op1_is_imm && (to_be_calculated[i].inst_info.reserevation_entry.inst.is_branch || to_be_calculated[i].inst_info.reserevation_entry.inst.is_jump)) begin
                alu_input_a[i] = to_be_calculated[i].inst_info.reserevation_entry.inst.pc_curr; 
            end
            else begin
                rs1_s_dispatch_request = to_be_calculated[i].inst_info.reserevation_entry.inst.rs1_s; 
                alu_input_a[i] = source_reg_1.register_value; 
            end

            if(op2_is_imm && ~to_be_calculated[i].inst_info.reserevation_entry.inst.is_branch && ~to_be_calculated[i].inst_info.reserevation_entry.inst.is_jump) begin
                alu_input_b[i] = to_be_calculated[i].inst_info.reserevation_entry.inst.immediate; 
            end
            else if(op2_is_imm && (to_be_calculated[i].inst_info.reserevation_entry.inst.is_branch || to_be_calculated[i].inst_info.reserevation_entry.inst.is_jump)) begin
                alu_input_b[i] = to_be_calculated[i].inst_info.reserevation_entry.inst.pc_curr; 
            end
            else begin
                rs2_s_dispatch_request = to_be_calculated[i].inst_info.reserevation_entry.inst.rs2_s; 
                alu_input_b[i] = source_reg_2.register_value; 
            end
        end
    end  

    always_comb begin
        cmp_input_a = alu_input_a; 
        cmp_input_b = alu_input_b; 
        for(int i = 0; i < SS; i++) begin
            if(to_be_calculated[i].inst_info.reserevation_entry.inst.is_branch) begin
                rs1_s_dispatch_request = to_be_calculated[i].inst_info.reserevation_entry.inst.rs1_s; 
                cmp_input_a[i] = source_reg_1.register_value; 
                rs2_s_dispatch_request = to_be_calculated[i].inst_info.reserevation_entry.inst.rs2_s; 
                cmp_input_b[i] = source_reg_2.register_value; 
            end
        end
    end

    // idk what to do for this
    assign alu_status[SS] = '1; 

    logic mult_done [SS]; 
    always_comb begin
        for(int i = 0; i < SS; i++) begin
            mult_status[i] = mult_done[i]; 
        end
    end

    logic [31:0] alu_output [SS]; 
    logic [31:0] cmp_output [SS]; 
    logic [31:0] mult_output [SS]; 

    generate 
        for(genvar i = 0; i < SS; i++) begin: FUs
            alu calculator(.aluop(to_be_calculated[i].inst_info.reserevation_entry.inst.alu_operation), 
                           .a(alu_input_a[i]), 
                           .b(alu_input_b[i]), 
                           .f(alu_output[i])); 
            cmp comparator(.cmpop(to_be_calculated[i].inst_info.reserevation_entry.inst.cmp_operation), 
                           .a(cmp_input_a), 
                           .b(cmp_input_b), 
                           .f(cmp_output[i])); 
            shift_add_multiplier(.clk(clk), 
                                 .rst(rst), 
                                 .start(to_be_calculated[i].start), 
                                 .mul_type(to_be_calculated[i].inst_info.reserevation_entry.inst.mul_type), 
                                 .a(alu_input_a[i]), 
                                 .b(alu_input_b[i]), 
                                 .p(mult_output[i]), 
                                 .done(mult_status[i]));
        end
    endgenerate   

    always_ff @ (posedge clk) begin
        fu_output.inst_info = to_be_calculated[i].inst_info.reserevation_entry; 
        for(int i = 0; i < SS; i++) begin
            if(to_be_calculated[i].inst_info.reserevation_entry.inst.alu_en) begin
                fu_output[i].register_value = alu_output[i];
                fu_output[i].ready_for_writeback = '1; 
            end
            else if(to_be_calculated[i].inst_info.reserevation_entry.inst.is_mul
                    && mult_status[i]) begin
                fu_output[i].register_value = mult_output[i];
                fu_output[i].ready_for_writeback = '1; 
            end
            else if(to_be_calculated[i].inst_info.reserevation_entry.inst.cmp_en) begin
                fu_output[i].register_value = {31'd0, cmp_output};
                fu_output[i].ready_for_writeback = '1; 
            end
        end
    end  
    
endmodule : fu_wrapper
    
