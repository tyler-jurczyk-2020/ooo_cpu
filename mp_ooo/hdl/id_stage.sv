module id_stage
    import rv32i_types::*;
    (   

        input logic [31:0] imem_rdata,
        input logic [31:0] pc_curr,

        output instruction_info_reg_t instruction_info
    );
    
    logic   [2:0]   funct3;
    logic   [6:0]   funct7;
    logic   [6:0]   opcode;
    logic   [31:0]  i_imm;
    logic   [31:0]  s_imm;
    logic   [31:0]  b_imm;
    logic   [31:0]  u_imm;
    logic   [31:0]  j_imm;
    logic   [4:0]   rs1_s;
    logic   [4:0]   rs2_s;
    logic   [4:0]   rd_s;   
    logic   [11:0]  offset;

    assign funct3 = imem_rdata[14:12];
    assign funct7 = imem_rdata[31:25];
    assign opcode = imem_rdata[6:0];
    assign i_imm  = {{21{imem_rdata[31]}}, imem_rdata[30:20]};
    assign s_imm  = {{21{imem_rdata[31]}}, imem_rdata[30:25], imem_rdata[11:7]};
    assign b_imm  = {{20{imem_rdata[31]}}, imem_rdata[7], imem_rdata[30:25], imem_rdata[11:8], 1'b0};
    assign u_imm  = {imem_rdata[31:12], 12'h000};
    assign j_imm  = {{12{imem_rdata[31]}}, imem_rdata[19:12], imem_rdata[20], imem_rdata[30:21], 1'b0};
    assign rs1_s  = imem_rdata[19:15];
    assign rs2_s  = imem_rdata[24:20];
    assign rd_s   = imem_rdata[11:7];
    assign offset = imem_rdata[31:20];

    always_comb begin
        instruction_info.funct3 = funct3; 
        instruction_info.funct7 = funct7; 
        instruction_info.opcode = opcode; 
        instruction_info.rs1_s = rs1_s; 
        instruction_info.rs2_s = rs2_s; 
        instruction_info.rd_s = rd_s; 
        instruction_info.valid = '1; // Instruction going into instruction queue will always be valid 
        // Replace immediate with one immediate 
        instruction_info.immediate = u_imm; 

        // add signal for if rs1 and rs2 is needed or not
        instruction_info.execute_operand1 = 2'b00; 
        instruction_info.execute_operand2 = 2'b00; 

        // Add signal on whether operands will be an immediate or not
        // instruction_info.op1_is_imm = '0; 
        // instruction_info.op2_is_imm = '0; 

        // TYPE | OP | (RS1, RS2) NEEDED | (Operand1, Operand2) is immediate or PC
        // U-Type: neither (umm + 0) (No, No) (Yes, Yes)
        // R-Type: R1 + R2 (Yes, Yes) (No, No)
        // I-Type: R1 + imm (Yes, No) (No, Yes)
        // S-type: R1 + smm => [R2] (Yes, Yes) (No, Yes)
        // B-Type: CMP R1 & R2, ALU PC + bmm (Yes, Yes) (Yes, Yes)
        // J-type: neither PC + 4, PC + jmm (No, No) (Yes, Yes)

        // instruction_info.alu_en = '1; 
        // instruction_info.cmp_en = '1;  
        instruction_info.is_branch = '0;  
        instruction_info.is_jump = '0;
        instruction_info.is_mul = '0;
        instruction_info.alu_operation = alu_add; 
        // instruction_info.cmp_operation = funct3;
        instruction_info.inst = imem_rdata;

        instruction_info.pc_curr = pc_curr; 
        // Not considering branches for now
        instruction_info.pc_next = pc_curr + 4; 

        instruction_info.is_mul = 1'b0;
        instruction_info.mul_type = 'x;

        // Memory mask
        instruction_info.rmask = '0;
        instruction_info.wmask = '0;

        instruction_info.is_signed = '0;
        // calculating branch target 
        // logic [31:0] b_imm;    // Branch immediate extracted from the instruction
        // logic [31:0] branch_target;

        // // b_imm is extracted from the instruction and is the raw bits from the instruction
        // assign b_imm = {{20{imem_rdata[31]}}, imem_rdata[7], imem_rdata[30:25], imem_rdata[11:8], 1'b0};

        // // Calculate branch target
        // assign branch_target = pc_curr + $signed(b_imm);



        unique case (opcode) 
            op_b_reg : begin 
                // default for mult type & enable signal
                

                // using M extension for multiplication:
                if (funct7 == 7'b0000001)begin
                    unique case (funct3)
                        3'b000, 3'b001: begin// mulh: signed * signed
                            instruction_info.mul_type = 2'b01; // signed multiplication
                        end
                        3'b010: begin// mulhsu: signed * unsigned
                            instruction_info.mul_type = 2'b10; // mixed un/signed multiplication
                        end
                        3'b011: begin// mulhu: unsigned * unsigned
                            instruction_info.mul_type = 2'b00; // unsigned multiplication
                        end
                        default : instruction_info.mul_type = 'x;
                    endcase
                    instruction_info.is_mul = 1'b1; // this instr is multiplying
                    // instruction_info.alu_en = '0;
                    // instruction_info.cmp_en = '0;
                    instruction_info.alu_operation = '0;
                end
                else begin
                    unique case (funct3)  
                        slt: begin
                            // instruction_info.cmp_operation = blt;
                            // instruction_info.alu_en = 1'b0;
                        end
                        sltu: begin
                            // instruction_info.cmp_operation = bltu;
                            // instruction_info.alu_en = 1'b0;
                        end
                        sr: begin
                            if (funct7[5]) begin
                                instruction_info.alu_operation = alu_sra;
                            end else begin
                                instruction_info.alu_operation = alu_srl;
                            end
                            // instruction_info.cmp_operation = funct3; 
                        end
                        add: begin
                            if (funct7[5]) begin
                                instruction_info.alu_operation = alu_sub;
                            end else begin
                                instruction_info.alu_operation = alu_add;
                            end
                            // instruction_info.cmp_operation = funct3; 
                        end
                        default : begin
                            instruction_info.alu_operation = funct3; 
                            // instruction_info.cmp_operation = funct3; 
                        end
                    endcase
                end

            end
            op_b_imm : begin 
                instruction_info.execute_operand1 = 2'b00; 
                instruction_info.execute_operand2 = 2'b11; 
                instruction_info.immediate = i_imm;
                // Hardwire rs2 to 0 since its not needed
                instruction_info.rs2_s = '0;
                unique case (funct3)
                    slt: begin
                        // instruction_info.cmp_operation = blt;
                        // instruction_info.alu_en = 1'b0;
                    end
                    sltu: begin
                        // instruction_info.cmp_operation = bltu;
                        // instruction_info.alu_en = 1'b0;
                    end
                    sr: begin
                        if (funct7[5]) begin
                            instruction_info.alu_operation = alu_sra;
                        end else begin
                            instruction_info.alu_operation = alu_srl;
                        end
                        // instruction_info.cmp_operation = funct3; 
                    end
                    default : begin
                        instruction_info.alu_operation = funct3; 
                        // instruction_info.cmp_operation = funct3; 
                    end
                endcase
            end
            op_b_auipc : begin
                instruction_info.execute_operand1 = 2'b11; 
                instruction_info.execute_operand2 = 2'b11; 
                instruction_info.immediate = u_imm;
                instruction_info.alu_operation = alu_add; 
                // instruction_info.cmp_operation = '0; 
            end
            op_b_br : begin
                instruction_info.execute_operand1 = 2'b00; 
                instruction_info.execute_operand2 = 2'b00; 
                instruction_info.immediate = b_imm; 
                instruction_info.is_branch = '1;   
            end
            op_b_jal : begin
                instruction_info.execute_operand1 = 2'b11; 
                instruction_info.execute_operand2 = 2'b11; 
                instruction_info.immediate = j_imm; 
                instruction_info.is_jump = '1;   
                // instruction_info.cmp_en = '0;  
            end
            op_b_jalr : begin
                instruction_info.execute_operand1 = 2'b11; 
                instruction_info.execute_operand2 = 2'b11; 
                instruction_info.immediate = j_imm; 
                instruction_info.is_jump = '1;   
                // instruction_info.cmp_en = '0;  
            end 
            op_b_load : begin
                instruction_info.execute_operand1 = 2'b00; 
                instruction_info.execute_operand2 = 2'b11; 
                instruction_info.immediate = i_imm; 
                // instruction_info.cmp_en = '0;  
                // Note that these masked are unshifted and need to be shifted in lsq
                unique case (funct3)
                    lb, lbu : instruction_info.rmask = 4'h1;
                    lh, lhu : instruction_info.rmask = 4'h3;
                    lw : instruction_info.rmask = 4'hf;
                    default : instruction_info.rmask = 'x;
                endcase
                unique case (funct3)
                    lb, lh, lw : instruction_info.is_signed = 1'b1;
                    lbu, lhu : instruction_info.is_signed = 1'b0;
                    default : instruction_info.rmask = 'x;
                endcase
            end
            op_b_store : begin
                instruction_info.execute_operand1 = 2'b00; 
                instruction_info.execute_operand2 = 2'b11; 
                instruction_info.immediate = s_imm; 
                // instruction_info.cmp_en = '1;  
                unique case (funct3)
                    sb : instruction_info.wmask = 4'h1;
                    sh : instruction_info.wmask = 4'h3;
                    sw : instruction_info.wmask = 4'hf;
                    default : instruction_info.wmask = 'x;
                endcase
            end

            default : ; 
        endcase            
    end

    
    
    
    endmodule : id_stage
