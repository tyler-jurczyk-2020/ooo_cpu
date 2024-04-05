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

// Dummy read
logic dummy_dmem_resp;
logic [31:0] dummy_dmem_rdata;
assign dummy_dmem_resp = dmem_resp;
assign dummy_dmem_rdata = dmem_rdata;

///////////////////// ISSUE: PHYSICAL REGISTER FILE /////////////////////
// MODULE INPUTS DECLARATION 
cdb_t cdb [SS]; 
logic write_fu_enable [SS][FU_COUNT]; 
logic write_from_rob [SS];
logic [5:0] rob_dest_reg[SS]; 

logic [7:0] reservation_rob_id [SS * FU_COUNT];
physical_reg_request_t fu_request [SS], dispatch_request [SS], rob_request [SS];
physical_reg_response_t fu_reg_data [SS], dispatch_reg_data [SS], rob_reg_data [SS];
// MODULE OUTPUT DECLARATION
phys_reg_file #(.SS(SS)) reg_file (
    .clk(clk), 
    .rst(rst), 
    .regf_we('1), 
    .reservation_rob_id(reservation_rob_id),
    .cdb(cdb), 
    .rob_request(rob_request), .rob_reg_data(rob_reg_data),
    .dispatch_request(dispatch_request), .dispatch_reg_data(dispatch_reg_data),
    .fu_request(fu_request), .fu_reg_data(fu_reg_data)
    ); 

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
logic [$clog2(PR_ENTRIES)-1:0] sel_pr_rs1 [SS], sel_pr_rs2 [SS];
physical_reg_data_t pr_rs1 [SS], pr_rs2 [SS];

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
                   .dispatch_request(dispatch_request), .dispatch_reg_data(dispatch_reg_data),
                   .pop_inst_q(pop_inst_q),
                   .rs_entries(rs_entries) 
                   );

///////////////////// FREE LISTS /////////////////////
// MODULE INPUTS DECLARATION 

// MODULE OUTPUT DECLARATION

// MODULE INSTANTIATION
circular_queue #(.SS(SS), .QUEUE_TYPE(logic [5:0]), .INIT_TYPE(FREE_LIST), .DEPTH(64))
      free_list(.clk(clk), .rst(rst), .push('0), .out(free_list_regs), .pop(pop_inst_q));

// CYCLE 1 (UTILIZED IN CYCLE 0)

// MODULE INSTANTIATION

// CYCLE 1 (WRITTEN TO IN CYCLE 0)
///////////////////// ISSUE: ROB /////////////////////
// MODULE INPUTS DECLARATION 

// MODULE OUTPUT DECLARATION
dispatch_reservation_t rob_entries_to_commit [SS];
// MODULE INSTANTIATION
logic pop_from_rob;


rob #(.SS(SS)) rb(.clk(clk), .rst(rst), .dispatch_info(rs_entries), .rob_id_next(rob_id_next), .avail_inst(avail_inst), 
                  .cdb(cdb),
                  .pop_from_rob(pop_from_rob), .rob_entries_to_commit(rob_entries_to_commit));

// CYCLE 1 (WRITTEN TO BY OTHER ELEMENT IN CYCLE 1) (CYCLE 1 TAKES MULTIPLE CLK CYCLES)
///////////////////// ISSUE: RESERVATION STATIONS /////////////////////
// MODULE INPUTS DECLARATION 
logic mult_status [SS];
fu_input_t fu_input [SS];
// MODULE OUTPUT DECLARATION

// MODULE INSTANTIATION
reservation #(.SS(SS)) reservation_table(.clk(clk), .rst(rst),
                        .reservation_entry(rs_entries), 
                        .avail_inst(avail_inst), 
                        .cdb(cdb),
                        .reservation_rob_id(reservation_rob_id),
                        .mult_status(mult_status), 
                        .inst_for_fu(fu_input),
                        .fu_request(fu_request), 
                        .table_full(rs_full));


// CYCLE 2
///////////////////// EXECUTE: FUNCTIONAL UNITS /////////////////////
// MODULE INPUTS DECLARATION 
// MODULE OUTPUT DECLARATION

// MODULE INSTANTIATION

fu_wrapper #(.SS(SS), .reservation_table_size(), .ROB_DEPTH()) calculator(
                       .clk(clk), .rst(rst),
                       .to_be_calculated(fu_input), 
                       .mul_available(mult_status), 
                       .fu_reg_data(fu_reg_data),
                       .cdb(cdb));


// Temporary:
assign dmem_rmask = 4'b0;
assign dmem_wmask = 4'b0;

//RVFI Signals
// Must be hardwired to 2 to be consistent with rvfi_reference.json
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

// Signals designed for max 2-way superscalar
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
