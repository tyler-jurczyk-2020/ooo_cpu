/////////////////////////////////////////////////////////////
//  Maybe use some of your types from mp_pipeline here?    //
//    Note you may not need to use your stage structs      //
/////////////////////////////////////////////////////////////

package rv32i_types;

    localparam TABLE_ENTRIES = 64;
    localparam N_MUL = 1;
    localparam N_ALU = 1;

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

        // Take from mp_verif
    typedef enum bit [2:0] {
        beq  = 3'b000,
        bne  = 3'b001,
        blt  = 3'b100,
        bge  = 3'b101,
        bltu = 3'b110,
        bgeu = 3'b111
    } branch_funct3_t;

    typedef enum bit [2:0] {
        lb  = 3'b000,
        lh  = 3'b001,
        lw  = 3'b010,
        lbu = 3'b100,
        lhu = 3'b101
    } load_funct3_t;

    typedef enum bit [2:0] {
        sb = 3'b000,
        sh = 3'b001,
        sw = 3'b010
    } store_funct3_t;

    typedef enum bit [2:0] {
        add  = 3'b000, //check bit 30 for sub if op_reg opcode
        sll  = 3'b001,
        slt  = 3'b010,
        sltu = 3'b011,
        axor = 3'b100,
        sr   = 3'b101, //check bit 30 for logical/arithmetic
        aor  = 3'b110,
        aand = 3'b111
    } arith_funct3_t;

    typedef enum bit [2:0] {
        alu_add = 3'b000,
        alu_sll = 3'b001, 
        alu_sra = 3'b010,
        alu_sub = 3'b011,
        alu_xor = 3'b100,
        alu_srl = 3'b101,
        alu_or  = 3'b110,
        alu_and = 3'b111
    } alu_ops;

    typedef struct packed {
            logic   [2:0]   funct3;
            logic   [6:0]   funct7;
            logic   [6:0]   opcode;
            logic   [4:0]   rs1_s;
            logic   [4:0]   rs2_s;
            logic   [4:0]   rd_s;
            logic   [31:0]  immediate; 
            
            logic [2:0] alu_operation;
            logic [2:0] cmp_operation;
            // type of multiplication operation
            logic [1:0] mul_type;
            
            logic alu_en;
            logic cmp_en;

            logic is_branch;
            logic is_jump;

            // to let shift_add_multiplier know we multiplyin
            logic is_mul;

            bit valid;

            logic [31:0] inst;

            logic [31:0] pc_curr;
            logic [31:0] pc_next;
            
            // signals to determine required registers and alu operands
            logic [1:0] execute_operand1; 
            logic [1:0] execute_operand2; 


            // logic op1_is_imm; 
            // logic op2_is_imm; 
            // logic rs1_needed; 
            // logic rs2_needed; 

    } instruction_info_reg_t;

    // Add more things here . . .
    typedef struct packed {
        logic [31:0] fetch_pc_curr;  //rvfi pc_rdata
        // For rvfi purposes (fetch_pc_curr + 4)
        logic [31:0] fetch_pc_next; 
    } fetch_output_reg_t;

    
    typedef struct packed {
        logic [5:0] rs1, rs2, rd;
    } rat_t;

    typedef struct packed {
        logic valid;
        logic [63:0] order; 
        logic [31:0] inst;      
        
        logic [4:0] rs1_addr; 
        logic [4:0] rs2_addr; 
        logic [31:0] rs1_rdata; 
        logic [31:0] rs2_rdata; 
        
        logic [4:0] rd_addr;
        logic [31:0] rd_wdata;
        
        logic [31:0] pc_rdata; 
        logic [31:0] pc_wdata; 
        
        logic [31:0] mem_addr; 
        logic [3:0] mem_rmask; 
        logic [3:0] mem_wmask;
        logic [31:0] mem_rdata;
        logic [31:0] mem_wdata;
    } rvfi_t;
        
    typedef struct packed {
       logic [7:0] rob_id;
       logic commit;
       // Hardcoded ROB depth so it compiles
       // ROB entries to refer to for dependency
    } rob_t;
    
    typedef struct packed {
       logic input1_met; 
       logic input2_met; 
       logic [7:0] rs1_source; 
       logic [7:0] rs2_source; 
       logic full; 
    } reservation_entry_t; 

    typedef struct packed {
       rob_t rob;
       rvfi_t rvfi; 
       instruction_info_reg_t inst;
       rat_t rat;
       reservation_entry_t rs_entry;
    } super_dispatch_t;

    typedef enum logic {
        ZERO,
        FREE_LIST
    } initialization_t;

    typedef enum logic {
        ALU_T,
        MUL_T
    } reservation_table_type_t;
            
    typedef struct packed {
        logic [31:0] register_value; 
       // Hardcoded ROB depth so it compiles
        logic [7:0] ROB_ID; 
        logic dependency; 
    } physical_reg_data_t; 

    typedef struct packed {
        logic [$clog2(TABLE_ENTRIES)-1:0] rd_s, rs1_s, rs2_s; 
        physical_reg_data_t rd_v;
        logic rd_en;
    } physical_reg_request_t;

    typedef struct packed {
        physical_reg_data_t rs1_v, rs2_v;
    } physical_reg_response_t;

    typedef struct packed {
        // get entry from reservation station
        super_dispatch_t inst_info; 

        // signal to begin calculation 
        logic start_calculate; 
    } fu_input_t; 

    typedef struct packed {
        super_dispatch_t inst_info; 
        logic [31:0] register_value; 
        logic ready_for_writeback; 
    } fu_output_t; 

    typedef struct {
        fu_output_t alu_out [N_ALU];
        fu_output_t mul_out [N_MUL];
    } cdb_t;

    typedef struct packed {
        logic [1:0] mul_type; 
        logic [31:0] a; 
        logic [31:0] b; 
        logic start; 
    } multiply_FUs_t; 

endpackage

package cache_types;

    typedef enum bit [1:0] {
        idle_s,
        compare_tag_s,
        allocate_s,
        writeback_s
    } state_t;

    typedef enum bit [2:0] {
        A = 3'b000,
        B = 3'b001,
        C = 3'b010,
        D = 3'b011,
        F = 3'b111
    } way_t;

endpackage
