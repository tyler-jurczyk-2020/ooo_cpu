module cpu
import rv32i_types::*;
#(
    parameter SS = 2,
    parameter PR_ENTRIES = 64,
    parameter ROB_DEPTH = 7
)
(
    // Explicit dual port connections when caches are not integrated into design yet (Before CP3)
    input   logic           clk,
    input   logic           rst,

    output  logic   [31:0]  imem_addr,
    output  logic   [3:0]   imem_rmask,
    input   logic   [31:0]  imem_rdata,
    input   logic           imem_resp,

    output  logic   [31:0]  dmem_addr,
    output  logic   [3:0]   dmem_rmask,
    output  logic   [3:0]   dmem_wmask,
    input   logic   [31:0]  dmem_rdata,
    output  logic   [31:0]  dmem_wdata,
    input   logic           dmem_resp

    // Single memory port connection when caches are integrated into design (CP3 and after)
    /*
    output logic   [31:0]      bmem_addr,
    output logic               bmem_read,
    output logic               bmem_write,
    output logic   [63:0]      bmem_wdata,
    input logic               bmem_ready,

    input logic   [31:0]      bmem_raddr,
    input logic   [63:0]      bmem_rdata,
    input logic               bmem_rvalid
    */
);

///////////////////// INSTRUCTION QUEUE /////////////////////

logic inst_queue_full;
// says that two instructions are ready for the instruction queue
logic valid_buffer_flag;
fetch_output_reg_t if_id_reg, if_id_reg_next;
// two valid instructions for SS
instruction_info_reg_t valid_inst[SS];
// singular decoded inst output from decode stage
instruction_info_reg_t decoded_inst;
// says that a instruction is reoutputady for the buffer
logic valid_inst_flag;

// Dummy assign 
assign dmem_addr = '0;
assign dmem_wdata = '0;

// Instruction Queue:
instruction_info_reg_t instruction [SS];
logic inst_q_empty, pop_inst_q;
circular_queue #(.SS(SS)) instruction_queue
                (.clk(clk), .rst(rst), // Defaults to instruction queue type
                 .full(inst_queue_full), .in(valid_inst),
                 .out(instruction),
                 .push(valid_buffer_flag), .pop(pop_inst_q), .empty(inst_q_empty),
                 .out_bitmask('0), .in_bitmask('0), .reg_select_in(), .reg_select_out(), .reg_in());

///////////////////// INSTRUCTION FETCH (SIMILAR TO MP2) /////////////////////
logic reset_hack;

always_ff @(posedge clk) begin
    if(rst)
        reset_hack <= 1'b1;
    else if((imem_resp && ~inst_queue_full) || reset_hack)
        if_id_reg <= if_id_reg_next;
    else
        reset_hack <= 1'b0;
end

fetch_stage fetch_stage_i (
    .clk(clk),
    .rst(rst),
    .predict_branch('0), // Change this later
    .stall_inst(inst_queue_full), 
    .imem_resp(imem_resp), 
    .reset_hack(reset_hack),
    .branch_pc('0), // Change thveribleis later
    .fetch_output(if_id_reg_next)    
);

id_stage id_stage_i (
    .fetch_output(if_id_reg),
    // this is all ur fault J soumil u r slow
    // watch the fucking lectures u actual cocksucker imma touch u imma still touch u 
    .imem_rdata(imem_rdata),
    .instruction_info(decoded_inst)
);

two_inst_buff #(.SS(SS)) buff (
    .clk(clk), 
    .rst(rst), 
    .valid(valid_inst_flag), 
    .decoded_inst(decoded_inst), 
    .valid_inst(valid_inst), 
    .valid_out(valid_buffer_flag)
);


always_comb begin
    if(imem_resp && ~inst_queue_full)
        valid_inst_flag = 1'b1;
    else
        valid_inst_flag = 1'b0;
end

// Not correct, temporary
// Merge cdb 
cdb_t cdb [SS], cdb_alu, cdb_mul;
always_comb begin
    for(int i = 0; i < SS; i++) begin
        cdb[i][ALU] = cdb_alu[ALU];
        cdb[i][MUL] = cdb_mul[MUL];
    end
end

assign imem_rmask = '1;
assign imem_addr = if_id_reg_next.fetch_pc_curr;

// Cycle 0: 
///////////////////// Rename/Dispatch: Physical Register File /////////////////////
// MODULE INPUTS DECLARATION 
physical_reg_request_t dispatch_request [SS], rob_request [SS], fu_request [SS];
logic [7:0] reservation_rob_id [SS * FU_COUNT];
// MODULE OUTPUT DECLARATION
physical_reg_response_t dispatch_reg_data [SS], fu_reg_data [SS];
// MODULE INSTANTIATION
phys_reg_file #(.SS(SS), .TABLE_ENTRIES(TABLE_ENTRIES), .ROB_DEPTH(ROB_DEPTH)) reg_file (
                .clk(clk), 
                .rst(rst), 
                .regf_we('1), 

                .reservation_rob_id(reservation_rob_id),
                
                .dispatch_request(dispatch_request), .dispatch_reg_data(dispatch_reg_data), 
                .fu_request(fu_request), .fu_reg_data(fu_reg_data),
                .rob_request(rob_request)
                ); 

// Cycle 0: 
///////////////////// Rename/Dispatch: Dispatcher /////////////////////

// MODULE INPUTS DECLARATION 
logic rs_full; 

// Input Arch. Reg. for RAT
logic [4:0] isa_rs1[SS], isa_rs2[SS]; // OUTPUTS
// Output of RAT
logic [5:0] rat_rs1[SS], rat_rs2[SS]; // INPUTS
// Phys Reg to Update Mapping for
logic [4:0] isa_rd[SS]; // OUTPUT
// New Phys RD for ISA RD
logic [5:0] rat_rd[SS]; // INPUT

// Free list output from a pop
logic [5:0] free_rat_rds [SS]; // INPUT

// Wish to check dependency for source registers
logic [$clog2(PR_ENTRIES)-1:0] dispatch_pr_rs1_s [SS], dispatch_pr_rs2_s [SS]; // OUTPUTS

// ROB ID Associated with current instruction
logic [$clog2(ROB_DEPTH)-1:0] rob_id_next [SS]; // INPUTS

logic avail_inst; 

// MODULE OUTPUT DECLARATION
super_dispatch_t rs_rob_entry [SS]; 

// MODULE INSTANTIATION
dispatcher #(.SS(SS), .PR_ENTRIES(PR_ENTRIES), .ROB_DEPTH(ROB_DEPTH)) dispatcher_i(
             .clk(clk), .rst(rst), 
             .pop_inst_q(pop_inst_q), // Needs to connect to free list as well
             .avail_inst(avail_inst),
             
             .rs_full('0), // Resevation station informs that must stall pipeline (stop requesting pops)
             .inst_q_empty(inst_q_empty), // to prevent pop requests to free list
             
             .inst(instruction), 
             
             // RAT
             .isa_rs1(isa_rs1), .isa_rs2(isa_rs2), 
             .rat_rs1(rat_rs1), .rat_rs2(rat_rs2), 
             .isa_rd(isa_rd), .rat_rd(rat_rd), 
            
             // Free List Popped Inst
             .free_rat_rds(free_rat_rds), 

             // Identify Dependencies for Curr Inst
             .dispatch_request(dispatch_request), .dispatch_reg_data(dispatch_reg_data),
             
             // ROB ID for CUR INST
             .rob_id_next(rob_id_next), 
             
             .rs_rob_entry(rs_rob_entry)
            ); 


// Cycle 0: 
///////////////////// Rename/Dispatch: RAT + RRAT /////////////////////
// MODULE INPUTS DECLARATION 
logic pop_from_rob;
logic [5:0] retire_to_free_list [SS];
super_dispatch_t rob_entries_to_commit [SS];
// MODULE OUTPUT DECLARATION

// MODULE INSTANTIATION
rat #(.SS(SS)) rt(.clk(clk), .rst(rst), .regf_we(avail_inst), // Need to connect write enable to pop_inst_q?
     .rat_rd(rat_rd),
     .isa_rd(isa_rd), .isa_rs1(isa_rs1), .isa_rs2(isa_rs2),
     .rat_rs1(rat_rs1) , .rat_rs2(rat_rs2)
     );

retired_rat #(.SS(SS)) retire_ratatoullie(
    .clk(clk), .rst(rst),
    .retire_we(pop_from_rob),
    .free_list_entry(retire_to_free_list),
    .rob_info(rob_entries_to_commit)
);

// Cycle 0: 
///////////////////// Rename/Dispatch: Free Lists /////////////////////
// MODULE INPUTS DECLARATION 
// MODULE OUTPUT DECLARATION

// MODULE INSTANTIATION

circular_queue #(.SS(SS), .QUEUE_TYPE(logic [5:0]), .INIT_TYPE(FREE_LIST), .DEPTH(64))
      free_list(.clk(clk), .rst(rst), .push(pop_from_rob), .out(free_rat_rds), .in(retire_to_free_list), .pop(pop_inst_q));
    
// Cycle 0: 
///////////////////// Rename/Dispatch: ROB /////////////////////
// MODULE INPUTS DECLARATION 

// MODULE OUTPUT DECLARATION

// MODULE INSTANTIATION
rob #(.SS(SS), .ROB_DEPTH(ROB_DEPTH)) rb(.clk(clk), .rst(rst), 
                                         .avail_inst(avail_inst), .dispatch_info(rs_rob_entry), 
                                         .cdb(cdb),
                                         .rob_request(rob_request), .rob_id_next(rob_id_next), 
                                         .rob_entries_to_commit(rob_entries_to_commit),
                                         .pop_from_rob(pop_from_rob)
                                        );

// Cycle 1: 
///////////////////// Issue: Reservation Station /////////////////////
// MODULE INPUTS DECLARATION 
logic FU_ready;

// MODULE OUTPUT DECLARATION
fu_input_t fu_input;

reservation #(.SS(SS)) reservation_table(.clk(clk), .rst(rst),
                                        .reservation_entry(rs_rob_entry), 
                                        .avail_inst(avail_inst), 
                                        .cdb(cdb),
                                        .reservation_rob_id(reservation_rob_id),
                                        .inst_for_fu(fu_input),
                                        .fu_request(fu_request), 
                                        .table_full(rs_full)
                                        );
// Cycle 2: 
///////////////////// Issue: Functional Units /////////////////////
// MODULE INPUTS DECLARATION 
// MODULE OUTPUT DECLARATION

fu_wrapper #(.SS(SS), .ROB_DEPTH(ROB_DEPTH)) 
   fuck_u(
        .clk(clk),.rst(rst),
        .to_be_calculated(fu_input),
        .cdb(cdb_alu),
        .fu_reg_data(fu_reg_data)    
  ); 

fu_wrapper_mult #(.SS(SS), .ROB_DEPTH(ROB_DEPTH)) 
   fuck_mu(
        .clk(clk),.rst(rst),
        .to_be_multiplied(fu_input),
        .cdb_multiply(cdb_mul),
        .FU_ready(FU_ready),
        .fu_reg_data(fu_reg_data)    
  ); 

// Temporary:
assign dmem_rmask = 4'b0;
assign dmem_wmask = 4'b0;

// //RVFI Signals
// // Must be hardwired to 2 to be consistent with rvfi_reference.json
logic           valid [2];
logic   [63:0]  order [2];
logic   [31:0]  inst [2];
logic           halt [2];
logic   [4:0]   rs1_addr [2];
logic   [4:0]   rs2_addr [2];
logic   [31:0]  rs1_rdata [2];
logic   [31:0]  rs2_rdata [2];
logic   [4:0]   rd_addr [2];
logic   [31:0]  rd_wdata [2];
//////////////////////////
logic   [31:0]  pc_rdata [2];
logic   [31:0]  pc_wdata [2];
logic   [31:0]  mem_addr [2];
logic   [3:0]   mem_rmask [2];
logic   [3:0]   mem_wmask [2];
logic   [31:0]  mem_rdata [2];
logic   [31:0]  mem_wdata [2];

always_comb begin
    // when we commit an instr 
    for(int i = 0; i < 2; i++) begin
        if(pop_from_rob && i < SS) begin
            valid[i] = rob_entries_to_commit[i].rvfi.valid;
            order[i] = rob_entries_to_commit[i].rvfi.order;
            inst[i] = rob_entries_to_commit[i].rvfi.inst;
            
            rs1_addr[i] = rob_entries_to_commit[i].rvfi.rs1_addr;
            rs2_addr[i] = rob_entries_to_commit[i].rvfi.rs2_addr;
            rs1_rdata[i] = rob_entries_to_commit[i].rvfi.rs1_rdata;
            rs2_rdata[i] = rob_entries_to_commit[i].rvfi.rs2_rdata;
            
            rd_addr[i] = rob_entries_to_commit[i].rvfi.rd_addr;
            rd_wdata[i] = rob_entries_to_commit[i].rvfi.rd_wdata;
            
            pc_rdata[i] = rob_entries_to_commit[i].rvfi.pc_rdata;
            pc_wdata[i] = rob_entries_to_commit[i].rvfi.pc_wdata;
            
            mem_addr[i] = rob_entries_to_commit[i].rvfi.mem_addr;
            mem_rmask[i] = rob_entries_to_commit[i].rvfi.mem_rmask;
            mem_wmask[i] = rob_entries_to_commit[i].rvfi.mem_wmask;
            mem_rdata[i] = rob_entries_to_commit[i].rvfi.mem_rdata;
            mem_wdata[i] = rob_entries_to_commit[i].rvfi.mem_wdata;
        end
        else begin
            valid[i] = 1'b0;
            order[i] = 'x;
            inst[i] = 'x;
            
            rs1_addr[i] = 'x;
            rs2_addr[i] = 'x;
            rs1_rdata[i] = 'x;
            rs2_rdata[i] = 'x;

            rd_addr[i] = 'x;
            rd_wdata[i] = 'x;
            
            pc_rdata[i] = 'x;
            pc_wdata[i] = 'x;
            
            mem_addr[i] = 'x;
            mem_rmask[i] = 'x;
            mem_wmask[i] = 'x;
            mem_rdata[i] = 'x;
            mem_wdata[i] = 'x;
        end
    end
end


endmodule : cpu
