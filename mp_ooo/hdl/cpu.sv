module cpu
import rv32i_types::*;
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
    output  logic   [31:0]  dmem_imem_addr,
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

// Circular queue
logic [394:0] valid_inst_conversion [2];
assign valid_inst_conversion[0] = valid_inst[0].megaword;
assign valid_inst_conversion[1] = valid_inst[1].megaword;

// Test logic to read out. To be removed
logic pop_queue;
logic empty;
always_ff @(posedge clk) begin
    if(rst)
        pop_queue <= 1'b0;
    else if(inst_queue_full && ~empty)
        pop_queue <= 1'b1;
    else
        pop_queue <= 1'b0;
end

circular_queue #(.WIDTH(395)) cq(.clk(clk), .rst(rst), .full(inst_queue_full), .in(valid_inst_conversion),
                 .push(valid_buffer_flag), .pop(pop_queue), .empty(empty));

// Temporary 
assign dmem_rmask = 4'b0;
assign dmem_wmask = 4'b0;

///////////////////// INSTRUCTION FETCH (SIMILAR TO MP2) /////////////////////

fetch_output_reg_t if_id_reg, if_id_reg_next;

fetch_stage fetch_stage_i (
    .clk(clk), 
    .rst(rst), 
    .predict_branch('0), // Change this later
    .stall_inst(inst_queue_full), 
    .branch_pc('0), // Change thveribleis later
    .fetch_output(if_id_reg_next)    
);

// singular decoded inst output from decode stage
instruction_info_reg_t decoded_inst;
// two valid instructions for superscalar
instruction_info_reg_t valid_inst[2];
// says that a instruction is ready for the buffer
logic valid_inst_flag; 

id_stage id_stage_i (
    .clk(clk),
    .rst(rst),
    .fetch_output(if_id_reg),
    .imem_rdata(imem_rdata),
    .imem_resp(imem_resp),
    .stall_inst(inst_queue_full),
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
