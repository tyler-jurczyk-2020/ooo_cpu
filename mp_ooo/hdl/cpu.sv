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

///////////////////// INSTRUCTION FETCH (SIMILAR TO MP2) /////////////////////

fetch_output_reg_t if_id_reg, if_id_reg_next;

fetch_stage fetch_stage_i (
    .clk(clk), 
    .rst(rst), 
    .predict_branch('0), // Change this later
    .stall_inst(inst_queue_full), 
    .branch_pc('0) // Change this later
    .fetch_output(if_id_reg_next)    
)



always_ff @ (posedge clk) begin
    if(imem_resp && ~inst_queue_full)
        if_id_reg <= if_id_reg_next; 
end

assign imem_rmask = '1; 
assign imem_rdata = if_id_reg_next.fetch_pc_curr; 


endmodule : cpu
