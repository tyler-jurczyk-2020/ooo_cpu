/////////////////////////////////////////////////////////////
//  Maybe use some of your types from mp_pipeline here?    //
//    Note you may not need to use your stage structs      //
/////////////////////////////////////////////////////////////

package rv32i_types;

    typedef enum logic [6:0] {
        op_b_lui   = 7'b0110111, // U load upper immediate 
        op_b_auipc = 7'b0010111, // U add upper immediate PC 
        op_b_jal   = 7'b1101111, // J jump and link 
        op_b_jalr  = 7'b1100111, // I jump and link register 
        op_b_br    = 7'b1100011, // B branch 
        op_b_load  = 7'b0000011, // I load 
        op_b_store = 7'b0100011, // S store 
        op_b_imm   = 7'b0010011, // I arith ops with register/immediate operands 
        op_b_reg   = 7'b0110011, // R arith ops with register operands 
        op_b_csr   = 7'b1110011  // I control and status register 
    } rv32i_op_b_t;

    typedef struct packed {
        logic   [2:0]   funct3;
        logic   [6:0]   funct7;
        logic   [6:0]   opcode;
        logic   [4:0]   rs1_s;
        logic   [4:0]   rs2_s;
        logic   [4:0]   rd_s;   

        logic   [31:0]  alu_operand_1;
        logic   [31:0]  alu_operand_2;
        logic   [31:0]  cmp_operand_1;
        logic   [31:0]  cmp_operand_1;
        logic [2:0] alu_operation; 
        logic [2:0] cmp_operation; 
        logic alu_en; 
        logic cmp_en; 

        logic is_branch; 
        logic is_jump; 
        bit valid; 

        logic   [31:0]  i_imm;
        logic   [31:0]  s_imm;
        logic   [31:0]  b_imm;
        logic   [31:0]  u_imm;
        logic   [31:0]  j_imm;
    } instruction_info_reg_t;

    // Add more things here . . .
    typedef struct packed {
        logic [31:0] fetch_pc_curr, //rvfi pc_rdata
        // For rvfi purposes (fetch_pc_curr + 4)
        logic [31:0] fetch_pc_wdata
    } fetch_output_reg_t;


endpackage
