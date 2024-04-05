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


// Dummy signals, to be removed
// logic dummy_dmem_resp;
// logic [31:0] dummy_dmem_data;
// logic [1:0] dummy [SS];
// instruction_info_reg_t dummy_reg [SS];
// assign dummy_dmem_resp = dmem_resp;
// assign dummy_dmem_data = dmem_rdata;
// assign dummy[0] = '0;
// assign dummy[1] = '0;
// assign dummy_reg[0] = '0;
// assign dummy_reg[1] = '0;

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

assign imem_rmask = '1;
assign imem_addr = if_id_reg_next.fetch_pc_curr;

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
physical_reg_data_t pr_rs1 [SS], pr_rs2 [SS]; // INPUTS

// ROB ID Associated with current instruction
logic [$clog2(ROB_DEPTH)-1:0] rob_id_next [SS]; // INPUTS

logic avail_inst; 

// MODULE OUTPUT DECLARATION
super_dispatch_t rs_rob_entry [SS]; 

// MODULE INSTANTIATION
dispatcher #(.SS(SS), .PR_ENTRIES(PR_ENTRIES), .ROB_DEPTH(ROB_DEPTH)) dispatcher_i(
             .clk(clk), .rst(rst), 
             .pop_inst_q(pop_inst_q), // Needs to connect to free list as well
             .rs_full('0), // Resevation station informs that must stall pipeline (stop requesting pops)
             .inst_q_empty(inst_q_empty), // to prevent pop requests to free list
             .inst(instruction), 
             .avail_inst(avail_inst),

             // RAT
             .isa_rs1(isa_rs1), .isa_rs2(isa_rs2), 
             .rat_rs1(rat_rs1), .rat_rs2(rat_rs2), 
             .isa_rd(isa_rd), .rat_rd(rat_rd), 
            
             // Free List Popped Inst
             .free_rat_rds(free_rat_rds), 

             // Identify Dependencies for Curr Inst
             .dispatch_pr_rs1_s(dispatch_pr_rs1_s), .dispatch_pr_rs2_s(dispatch_pr_rs2_s), 
             .pr_rs1(pr_rs1), .pr_rs2(pr_rs2), 

             // ROB ID for CUR INST
             .rob_id_next(rob_id_next), 
             
             .rs_rob_entry(rs_rob_entry)); 


// Cycle 0: 
///////////////////// Rename/Dispatch: RAT /////////////////////
// MODULE INPUTS DECLARATION 
// MODULE OUTPUT DECLARATION

// MODULE INSTANTIATION
rat #(.SS(SS)) rt(.clk(clk), .rst(rst), .regf_we(avail_inst), // Need to connect write enable to pop_inst_q?
     .rat_rd(rat_rd),
     .isa_rd(isa_rd), .isa_rs1(isa_rs1), .isa_rs2(isa_rs2),
     .rat_rs1(rat_rs1) , .rat_rs2(rat_rs2)
     );

// Cycle 0: 
///////////////////// Rename/Dispatch: Free Lists /////////////////////
// MODULE INPUTS DECLARATION 
// MODULE OUTPUT DECLARATION

// MODULE INSTANTIATION

circular_queue #(.SS(SS), .QUEUE_TYPE(logic [5:0]), .INIT_TYPE(FREE_LIST), .DEPTH(64))
      free_list(.clk(clk), .rst(rst), .push('0), .out(free_rat_rds), .pop(pop_inst_q));


// Cycle 0: 
///////////////////// Rename/Dispatch: Physical Register File /////////////////////
// MODULE INPUTS DECLARATION 
// Signal stating that ROB has new dependency to store in phys reg file
logic write_from_rob [SS]; 
logic [5:0] rob_dest_reg[SS]; 
// MODULE OUTPUT DECLARATION

// MODULE INSTANTIATION
phys_reg_file #(.SS(SS), .TABLE_ENTRIES(TABLE_ENTRIES), .ROB_DEPTH(ROB_DEPTH)) reg_file (
    .clk(clk), 
    .rst(rst), 
    .regf_we('1), 
    // .reservation_rob_id(), // Inform Resevation Station that this ROB ID has been updated
    .rd_s_ROB_write_destination(rob_dest_reg), 
    .ROB_ID_for_new_inst(rob_id_next), 
    .write_from_fu(), 
    .write_from_rob(write_from_rob), 
    .rs1_s_dispatch_request(dispatch_pr_rs1_s), 
    .cdb(), 
    .rs2_s_dispatch_request(dispatch_pr_rs2_s), 
    .source_reg_1(pr_rs1), .source_reg_2(pr_rs2),
    .fu_request(), .fu_reg_data()
    ); 


// Cycle 0: 
///////////////////// Rename/Dispatch: ROB /////////////////////
// MODULE INPUTS DECLARATION 
// MODULE OUTPUT DECLARATION

// MODULE INSTANTIATION
rob #(.SS(SS), .ROB_DEPTH(ROB_DEPTH)) rb(.clk(clk), .rst(rst), .dispatch_info(rs_rob_entry), .rob_id_next(rob_id_next), .avail_inst(avail_inst), 
                  .cdb(),
                  .pop_from_rob(), .rob_entries_to_commit(), .rob_dest_reg(rob_dest_reg), .write_from_rob(write_from_rob));


// Cycle 1: 
///////////////////// Issue: Reservation Station /////////////////////
// MODULE INPUTS DECLARATION 
// MODULE OUTPUT DECLARATION








// // Temporary:
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

always_ff @ (posedge clk) begin
    if(rst) begin
        valid[0] <= '0; 
        valid[1] <= '0; 
    end
    else begin
        valid[0] <= '0; 
        valid[1] <= '0; 
    end
end


endmodule : cpu
