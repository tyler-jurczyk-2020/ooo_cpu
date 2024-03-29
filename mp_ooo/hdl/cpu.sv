module cpu
import rv32i_types::*;
#(
    parameter SS = 2
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
// says that a instruction is ready for the buffer
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
circular_queue #(.SS(SS)) instruction_queue(.clk(clk), .rst(rst), // Defaults to instruction queue type
                 .full(inst_queue_full), .in(valid_inst),
                 .out(instruction),
                 .push(valid_buffer_flag), .pop(pop_inst_q), .empty(inst_q_empty),
                 .out_bitmask('0), .in_bitmask('0), .reg_select_in(dummy), .reg_select_out(dummy), .reg_in(dummy_reg));

// Free List:
free_list_t free_list_regs[SS];
logic pop_free_list;
circular_queue #(.QUEUE_TYPE(free_list_t), .SS(SS)) free_list(.clk(clk), .rst(rst), .push('0), .out(free_list_regs), .pop(pop_free_list));

// RAT Instantiation:
logic modify_rat;
logic [5:0] rat_rs1[SS], rat_rs2[SS], rat_rd[SS];
logic [4:0] isa_rs1[SS], isa_rs2[SS], isa_rd[SS];

rat #(.SS(SS)) rt(.clk(clk), .rst(rst), .regf_we(modify_rat),
     .rat_rd(rat_rd),
     .isa_rd(isa_rd), .isa_rs1(isa_rs1), .isa_rs2(isa_rs2),
     
     .rat_rs1(rat_rs1) , .rat_rs2(rat_rs2)
     );

// Rename/Dispatch:
reservation_station_t rs_entries [SS];
rob_t rob_entry;
logic rs_enable, rs_full;

rename_dispatch #(.SS(SS)) rd(.clk(clk), .rst(rst), 
                   .rat_rs1(rat_rs1), .rat_rs2(rat_rs2),
                   .instruction(instruction),
                   .inst_q_empty(inst_q_empty),
                   .free_list_regs(free_list_regs),
                   .rs_full(rs_full),

                   .modify_rat(modify_rat), .rat_dest(rat_rd),
                   .isa_rs1(isa_rs1), .isa_rs2(isa_rs2), .isa_rd(isa_rd),
                   .pop_inst_q(pop_inst_q), .pop_free_list(pop_free_list),
                   .updated_rob(rob_entry),
                   .rs_enable(rs_enable), .rs_entries(rs_entries)
                   );

// Reservation Station: 
reservation #(.SS(SS)) rs(.info(rs_entries), .enable(rs_enable), .rs_full(rs_full));

// ROB:
rob #(.SS(SS)) rb(.cdb(rs_entries), .rob_entry(rob_entry));

// Temporary:
assign dmem_rmask = 4'b0;
assign dmem_wmask = 4'b0;

///////////////////// INSTRUCTION FETCH (SIMILAR TO MP2) /////////////////////

fetch_stage fetch_stage_i (
    .clk(clk),
    .rst(rst),
    .predict_branch('0), // Change this later
    .stall_inst(inst_queue_full),
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
