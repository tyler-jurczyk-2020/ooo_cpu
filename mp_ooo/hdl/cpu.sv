module cpu
import rv32i_types::*;
#(
    parameter SS = 2,
    parameter ROB_DEPTH = 8
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
    output  logic   [31:0]  bmem_addr,
    output  logic           bmem_read,
    output  logic           bmem_write,
    input   logic   [255:0] bmem_rdata,
    output  logic   [255:0] bmem_wdata,
    input   logic           bmem_resp
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
logic dummy_dmem_resp;
logic [31:0] dummy_dmem_data;
logic [1:0] dummy [SS];
instruction_info_reg_t dummy_reg [SS];
assign dummy_dmem_resp = dmem_resp;
assign dummy_dmem_data = dmem_rdata;
assign dummy[0] = '0;
assign dummy[1] = '0;
assign dummy_reg[0] = '0;
assign dummy_reg[1] = '0;
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
                 .out_bitmask('0), .in_bitmask('0), .reg_select_in(dummy), .reg_select_out(dummy), .reg_in(dummy_reg));

///////////////////// INSTRUCTION FETCH (SIMILAR TO MP2) /////////////////////

fetch_stage fetch_stage_i (
    .clk(clk),
    .rst(rst),
    .predict_branch('0), // Change this later
    .stall_inst(inst_queue_full), 
    .imem_resp(imem_resp), 
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

two_inst_buff buff (
    .clk(clk), 
    .rst(rst), 
    .valid(valid_inst_flag), 
    .decoded_inst(decoded_inst), 
    .valid_inst(valid_inst), 
    .valid_out(valid_buffer_flag)
);

always_ff @(posedge clk) begin
    if(imem_resp && ~inst_queue_full)
        if_id_reg <= if_id_reg_next;
end

always_comb begin
    if(imem_resp && ~inst_queue_full)
        valid_inst_flag = 1'b1;
    else
        valid_inst_flag = 1'b0;
end

assign imem_rmask = '1;
assign imem_addr = if_id_reg_next.fetch_pc_curr;

///////////////////// RAT /////////////////////
// MODULE INPUTS DECLARATION 
logic [5:0] rat_rs1[SS], rat_rs2[SS], rat_rd[SS];
logic [4:0] isa_rs1[SS], isa_rs2[SS], isa_rd[SS];

// MODULE OUTPUT DECLARATION

// MODULE INSTANTIATION

rat #(.SS(SS)) rt(.clk(clk), .rst(rst), .regf_we(), // Need to connect write enable to pop_inst_q?
     .rat_rd(rat_rd),
     .isa_rd(isa_rd), .isa_rs1(isa_rs1), .isa_rs2(isa_rs2),
     .rat_rs1(rat_rs1) , .rat_rs2(rat_rs2)
     );


// CYCLE 0
///////////////////// RENAME/DISPATCH /////////////////////
// MODULE INPUTS DECLARATION 
logic [5:0] free_list_regs[SS];
dispatch_reservation_t rs_entries [SS];
logic rs_full;
logic avail_inst;
logic [$clog2(ROB_DEPTH)-1:0] rob_id_next [SS];

// MODULE OUTPUT DECLARATION

// MODULE INSTANTIATION

rename_dispatch #(.SS(SS)) rd(.clk(clk), .rst(rst), 
                   .rat_rs1(rat_rs1), .rat_rs2(rat_rs2),
                   .instruction(instruction),
                   .inst_q_empty(inst_q_empty),
                   .free_list_regs(free_list_regs),
                   .rs_full(rs_full),
                   .avail_inst(avail_inst),
                   .rob_id_next(rob_id_next),

                   .rat_dest(rat_rd),
                   .isa_rs1(isa_rs1), .isa_rs2(isa_rs2), .isa_rd(isa_rd),
                   .pop_inst_q(pop_inst_q),
                   .rs_entries(rs_entries) 
                   );

///////////////////// FREE LISTS /////////////////////
// MODULE INPUTS DECLARATION 

// MODULE OUTPUT DECLARATION

// MODULE INSTANTIATION
circular_queue #(.QUEUE_TYPE(logic [5:0]), .INIT_TYPE(FREE_LIST), .DEPTH(64), .SS(SS))
free_list(.clk(clk), .rst(rst), .push('0), .out(free_list_regs), .pop(pop_inst_q));

// CYCLE 1 (UTILIZED IN CYCLE 0)
///////////////////// ISSUE: PHYSICAL REGISTER FILE /////////////////////
// MODULE INPUTS DECLARATION 

// MODULE OUTPUT DECLARATION
phys_reg_file reg_file (
    .clk(clk), 
    .rst(rst), 
    .regf_we('1), 
    .rd_s_ROB_write_destination(), 
    .ROB_ID_ROB_write_destination(), 
    .rd_v_FU_write_destination(), 
    .write_from_fu(), 
    .write_from_rob(), 
    .rs1_s_dispatch_request(), 
    .rs2_s_dispatch_request(), 
    .source_reg_1(), .source_reg_2()); 


// MODULE INSTANTIATION

// CYCLE 1 (WRITTEN TO IN CYCLE 0)
///////////////////// ISSUE: ROB /////////////////////
// MODULE INPUTS DECLARATION 

// MODULE OUTPUT DECLARATION

// MODULE INSTANTIATION

// CYCLE 1 (WRITTEN TO BY OTHER ELEMENT IN CYCLE 1) (CYCLE 1 TAKES MULTIPLE CLK CYCLES)
///////////////////// ISSUE: RESERVATION STATIONS /////////////////////
// MODULE INPUTS DECLARATION 

// MODULE OUTPUT DECLARATION

// MODULE INSTANTIATION

// CYCLE 2
///////////////////// EXECUTE: FUNCTIONAL UNITS /////////////////////
// MODULE INPUTS DECLARATION 

// MODULE OUTPUT DECLARATION

// MODULE INSTANTIATION





// Reservation Station: 
reservation #(.SS(SS)) rs(.clk(clk), .rst(rst),.reservation_entry(rs_entries), .table_full(rs_full), .avail_inst(avail_inst));

// ROB:
rob_t rob_entry;
rob #(.SS(SS)) rb(.clk(clk), .rst(rst), .rob_id_next(rob_id_next), .avail_inst(avail_inst));

// Temporary:
assign dmem_rmask = 4'b0;
assign dmem_wmask = 4'b0;

//RVFI Signals
logic           valid;
logic   [63:0]  order;
logic   [31:0]  inst;
logic           halt;
logic   [4:0]   rs1_addr;
logic   [4:0]   rs2_addr;
logic   [31:0]  rs1_rdata;
logic   [31:0]  rs2_rdata;
logic   [4:0]   rd_addr;
logic   [31:0]  rd_wdata;
logic   [31:0]  pc_rdata;
logic   [31:0]  pc_wdata;
logic   [31:0]  mem_addr;
logic   [3:0]   mem_rmask;
logic   [3:0]   mem_wmask;
logic   [31:0]  mem_rdata;
logic   [31:0]  mem_wdata;

assign valid = '0;
assign order = '0;
assign inst = '0;
assign rs1_addr = '0;
assign rs2_addr = '0;
assign rs1_rdata = '0;
assign rs2_rdata = '0;
assign rd_addr = '0;
assign rd_wdata = '0;
assign pc_rdata = '0;
assign pc_wdata = '0;
assign mem_addr = '0;
assign mem_rmask = '0;
assign mem_wmask = '0;
assign mem_rdata = '0;
assign mem_wdata = '0;

endmodule : cpu
