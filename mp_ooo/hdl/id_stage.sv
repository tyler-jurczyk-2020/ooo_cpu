module id_stage
    import rv32i_types::*;
    (   
        input   logic           clk,
        input   logic           rst,

        // DA PC to propogate for RVFI
        input output fetch_output_reg_t fetch_output, 

        input [31:0] imem_rdata, 
        input [31:0] imem_resp, 

        input stall_inst, 

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

    // typedef struct packed {
    //     logic   [2:0]   funct3;
    //     logic   [6:0]   funct7;
    //     logic   [6:0]   opcode;
    //     logic   [4:0]   rs1_s;
    //     logic   [4:0]   rs2_s;
    //     logic   [4:0]   rd_s;   

    //     logic   [31:0]  alu_operand_1;
    //     logic   [31:0]  alu_operand_2;
    //     logic   [31:0]  cmp_operand_1;
    //     logic   [31:0]  cmp_operand_1;
    //     logic [2:0] alu_operation; 
    //     logic [2:0] cmp_operation; 
    //     logic alu_en; 
    //     logic cmp_en; 

    //     logic is_branch; 
    //     logic is_jump; 
    //     bit valid; id_stage::
id_stage::
id_stage::
id_stage::
id_stage::
id_stage::
id_stage::
id_stage::
    // } instruction_info_reg_t;

    // // Add more things here . . .
    // typedef struct packed {
    //     logic [31:0] fetch_pc_curr, //rvfi pc_rdata
    //     // For rvfi purposes (fetch_pc_curr + 4)
    //     logic [31:0] fetch_pc_wdata
    // } fetch_output_reg_t;

    always_comb begin
        instruction_info.funct3 = funct3; 
        instruction_info.funct7 = funct7; 
        instruction_info.opcode = opcode; 
        instruction_info.rs1_s = rs1_s; 
        instruction_info.rs2_s = rs2_s; 
        instruction_info.rd_s = rd_s; 
        instruction_info.valid = '0; 
        instruction_info.i_imm = i_imm;
        instruction_info.s_imm = s_imm;
        instruction_info.b_imm = b_imm;
        instruction_info.u_imm = u_imm;
        instruction_info.j_imm = j_imm;

        unique case (opcode) 
            op_b_reg : begin 
                unique case (funct3)
                    instruction_info.alu_en = '1; 
                    instruction_info.cmp_en = '1;  
                    instruction_info.is_branch = '0;  
                    instruction_info.is_jump = '0;  
                    slt: begin
                        instruction_info.cmp_operation = blt;
                        instruction_info.alu_en = 1'b0;
                    end
                    sltu: begin
                        instruction_info.cmp_operation = bltu;
                        instruction_info.alu_en = 1'b0;
                    end
                    sr: begin
                        if (funct7[5]) begin
                            instruction_info.alu_operation = alu_sra;
                        end else begin
                            instruction_info.alu_operation = alu_srl;
                        end
                        instruction_info.cmp_operation = funct3; 
                    end
                    add: begin
                        if (funct7[5]) begin
                            instruction_info.alu_operation = alu_sub;
                        end else begin
                            instruction_info.alu_operation = alu_add;
                        end
                        instruction_info.cmp_operation = funct3; 
                    end
                    default : begin
                        instruction_info.alu_operation = funct3; 
                        instruction_info.cmp_operation = funct3; 
                    end
                endcase
            end
            op_b_imm : begin
                instruction_info.alu_en = '1; 
                instruction_info.cmp_en = '1;  
                instruction_info.is_branch = '0;  
                instruction_info.is_jump = '0;  

                unique case (funct3)
                    slt: begin
                        instruction_info.alu_operation = blt;
                        instruction_info.alu_en = 1'b0;
                    end
                    sltu: begin
                        instruction_info.alu_operation = bltu;
                        instruction_info.alu_en = 1'b0;
                    end
                    sr: begin
                        if (funct7[5]) begin
                            instruction_info.aluop = alu_sra;
                        end else begin
                            instruction_info.aluop = alu_srl;
                        end
                        instruction_info.alu_operation = funct3; 
                    end
                    default : begin
                        instruction_info.aluop = funct3; 
                        instruction_info.alu_operation = funct3; 
                    end
                endcase


    end

    
    
    
    endmodule : id_stage