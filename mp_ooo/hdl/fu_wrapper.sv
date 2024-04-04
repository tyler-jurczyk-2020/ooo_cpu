module fu_wrapper
    import rv32i_types::*;
    #(
        parameter SS = 2,
        parameter reservation_table_size = 8,
        parameter ROB_DEPTH = 7
    )
    (
        input logic clk, rst,
        // get entry from reservation station
        input fu_input_t to_be_calculated [SS], 

        output logic mult_status[SS],

        output fu_output_t fu_output [SS], 
        input physical_reg_response_t fu_reg_data [SS]

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

    always_comb begin
        for(int i = 0; i < SS; i++) begin
            // if(to_be_calculated[i].inst_info.reservation_entry.inst.op1_is_imm && ~to_be_calculated[i].inst_info.reservation_entry.inst.is_branch && ~to_be_calculated[i].inst_info.reservation_entry.inst.is_jump) begin
            //     alu_input_a[i] = to_be_calculated[i].inst_info.reservation_entry.inst.immediate; 
            // end
            if(to_be_calculated[i].inst_info.reservation_entry.inst.op1_is_imm && (to_be_calculated[i].inst_info.reservation_entry.inst.is_branch || to_be_calculated[i].inst_info.reservation_entry.inst.is_jump || (to_be_calculated[i].inst_info.reservation_entry.inst.opcode == op_b_auipc))) begin
                alu_input_a[i] = to_be_calculated[i].inst_info.reservation_entry.inst.pc_curr; 
            end
            else if(to_be_calculated[i].inst_info.reservation_entry.inst.rs1_s == 5'b0) begin
                alu_input_a[i] = '0;
            end
            else begin
                alu_input_a[i] = fu_reg_data[i].rs1_v.register_value; 
            end

            if(to_be_calculated[i].inst_info.reservation_entry.inst.op2_is_imm && ~to_be_calculated[i].inst_info.reservation_entry.inst.is_branch && ~to_be_calculated[i].inst_info.reservation_entry.inst.is_jump) begin
                alu_input_b[i] = to_be_calculated[i].inst_info.reservation_entry.inst.immediate; 
            end
            // else if(to_be_calculated[i].inst_info.reservation_entry.inst.op2_is_imm && (to_be_calculated[i].inst_info.reservation_entry.inst.is_branch || to_be_calculated[i].inst_info.reservation_entry.inst.is_jump)) begin
            //     alu_input_b[i] = to_be_calculated[i].inst_info.reservation_entry.inst.pc_curr; 
            // end
            else if(to_be_calculated[i].inst_info.reservation_entry.inst.rs2_s == 5'b0) begin
                alu_input_b[i] = '0;
            end
            else begin
                alu_input_b[i] = fu_reg_data[i].rs2_v.register_value; 
            end
        end
    end  

    always_comb begin
        cmp_input_a = alu_input_a; 
        cmp_input_b = alu_input_b; 
        for(int i = 0; i < SS; i++) begin
            if(to_be_calculated[i].inst_info.reservation_entry.inst.is_branch) begin
                cmp_input_a[i] = fu_reg_data[i].rs1_v.register_value; 
                cmp_input_b[i] = fu_reg_data[i].rs2_v.register_value; 
            end
        end
    end

    logic [31:0] alu_output [SS]; 
    logic cmp_output [SS]; 
    logic [63:0] mult_output [SS];

    generate 
        for(genvar i = 0; i < SS; i++) begin: FUs
            alu calculator(.aluop(to_be_calculated[i].inst_info.reservation_entry.inst.alu_operation), 
                           .a(alu_input_a[i]), 
                           .b(alu_input_b[i]), 
                           .f(alu_output[i])); 
            cmp comparator(.cmpop(to_be_calculated[i].inst_info.reservation_entry.inst.cmp_operation), 
                           .a(cmp_input_a[i]), 
                           .b(cmp_input_b[i]), 
                           .br_en(cmp_output[i])); 
            shift_add_multiplier shi(.clk(clk), 
                                 .rst(rst), 
                                 .start(to_be_calculated[i].start_calculate), 
                                 .mul_type(to_be_calculated[i].inst_info.reservation_entry.inst.mul_type), 
                                 .a(alu_input_a[i]), 
                                 .b(alu_input_b[i]), 
                                 .p(mult_output[i]), 
                                 .done(mult_status[i]));
        end
    endgenerate   

    always_ff @ (posedge clk) begin
        for(int i = 0; i < SS; i++) begin
            // setting commit flag that will be passed into rob
            // fu_output[i].inst_info.reservation_entry.rob.commit <= 1'b1;

            
            fu_output[i].inst_info <= to_be_calculated[i].inst_info; 
            if(to_be_calculated[i].inst_info.reservation_entry.inst.alu_en) begin
                fu_output[i].register_value <= alu_output[i];
                fu_output[i].ready_for_writeback <= '1; 
                fu_output[i].inst_info.reservation_entry.rvfi.rd_wdata <= alu_output[i];
            end
            else if(to_be_calculated[i].inst_info.reservation_entry.inst.is_mul
                    && mult_status[i]) begin
                fu_output[i].register_value <= mult_output[i];
                fu_output[i].ready_for_writeback <= '1; 
                fu_output[i].inst_info.reservation_entry.rvfi.rd_wdata <= mult_output[i];
            end
            // Probably need to fix. Shouldn't write out to rd during branches
            else if(to_be_calculated[i].inst_info.reservation_entry.inst.cmp_en) begin
                fu_output[i].register_value <= {31'd0, cmp_output[i]};
                fu_output[i].ready_for_writeback <= '1; 
            end
        end
    end  
        
endmodule : fu_wrapper
    