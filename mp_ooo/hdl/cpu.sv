module cpu
import rv32i_types::*;
#(
    parameter SS = 2,
    parameter PR_ENTRIES = 64,
    parameter reservation_table_size = 4,
    parameter DEPTH = 4,
    parameter ROB_DEPTH = 8
)
(
    input   logic           clk,
    input   logic           rst,

    // Single memory port connection when caches are integrated into design (CP3 and after)
    output logic   [31:0]      bmem_addr,
    output logic               bmem_read,
    output logic               bmem_write,
    output logic   [63:0]      bmem_wdata,
    input logic               bmem_ready,

    input logic   [31:0]      bmem_raddr,
    input logic   [63:0]      bmem_rdata,
    input logic               bmem_rvalid
);

// imem interface signals
logic   [31:0]   imem_addr;
logic            imem_rmask;
logic    [(32*SS)-1:0] imem_rdata;
logic            imem_resp;

// dmem interface signals
logic   [31:0]  dmem_addr;
logic           dmem_rmask;
logic   [3:0]   dmem_wmask;
logic   [31:0]  dmem_rdata;
logic   [31:0]  dmem_wdata;
logic           dmem_resp;

///////////////////// CACHE /////////////////////
// Instantiate caches here

cache_arbiter #(.SS(SS)) 
                ca(.clk(clk), .rst(rst),
                .bmem_itf_addr(bmem_addr),
                .bmem_itf_read(bmem_read) ,
                .bmem_itf_write(bmem_write),
                .bmem_itf_wdata(bmem_wdata),
                .bmem_itf_ready(bmem_ready),
                .bmem_itf_raddr(bmem_raddr),
                .bmem_itf_rdata(bmem_rdata),
                .bmem_itf_rvalid(bmem_rvalid),

                .imem_itf_addr(imem_addr),
                .imem_itf_rmask(imem_rmask),
                .imem_itf_rdata(imem_rdata),
                .imem_itf_resp(imem_resp),
                
                .dmem_itf_addr(dmem_addr),
                .dmem_itf_rmask(dmem_rmask),
                .dmem_itf_wmask(dmem_wmask),
                .dmem_itf_wdata(dmem_wdata),
                .dmem_itf_rdata(dmem_rdata),
                .dmem_itf_resp(dmem_resp)
);

///////////////////// INSTRUCTION QUEUE /////////////////////
logic inst_queue_full, flush;
// says that two instructions are ready for the instruction queue
fetch_output_reg_t if_id_reg, if_id_reg_next;
// Parsed out decoded cacheline
instruction_info_reg_t decoded_inst [SS];

super_dispatch_t rob_entries_to_commit1[SS]; 

logic valid_request; 


logic flush_reg; 

always_ff @ (posedge clk) begin
    if(rst) begin
        flush_reg <= '0; 
    end
    else if(flush) begin
        flush_reg <= '1; 
    end
    else if(imem_resp) begin
        flush_reg <= '0; 
    end
    
    
end

always_comb begin
    if(flush) begin
        valid_request = '0; 
    end
    else if(imem_resp && flush_reg) begin
        valid_request = '0; 
    end
    else if(imem_resp && ~flush_reg) begin
        valid_request = '1; 
    end
    else begin
        valid_request = '0; 
    end
end

// logic [31:0] pc_next [SS]; 

// Dummy assign
assign dmem_addr = '0;
assign dmem_wdata = '0;

// Dummy instruction assigns
logic [SS-1:0] d_bitmask;
logic [$clog2(ROB_DEPTH)-1:0] d_reg_sel [SS];
instruction_info_reg_t d_reg_in [SS];
always_comb begin
    d_bitmask = '0;
    for(int i = 0; i < SS; i++) begin
        d_reg_sel[i] = '0;
        d_reg_in[i] = '0;
    end
end

logic [31:0] pc_reg;

// Decoding 8 instructions
logic [31:0] unpacked_imem_rdata [SS];
logic [31:0] unpacked_pc [SS];

always_comb begin
    for(int i = 0; i < SS; i++) begin
        unpacked_imem_rdata[i] = imem_rdata[32*i+:32];
        unpacked_pc[i] = pc_reg + unsigned'(4*i);
    end
end

generate
    for(genvar i = 0; i < SS; i++) begin : parallel_decode
        id_stage id_stage_i (
            .predict_branch('0),
            .pc_curr(unpacked_pc[i]),
            .imem_rdata(unpacked_imem_rdata[i]),
            .instruction_info(decoded_inst[i])
            // .pc_next(pc_next[i])
        );
    end
endgenerate

// Instruction Queue(8 decoded instructions):
instruction_info_reg_t instruction [SS];
logic inst_q_empty, pop_inst_q;
instruction_info_reg_t view_inst_tail [1];
logic [$clog2(ROB_DEPTH)-1:0] inst_tail;
logic [$clog2(ROB_DEPTH)-1:0] sel_out_inst [1];
assign sel_out_inst[0] = inst_tail;

// Check if next inst has rd
logic next_inst_has_rd = view_inst_tail[0].has_rd;

// if we have a pop_from_rob, then we set a flag high (because that is the closest thing to knowing when pc is updated to some shit)
// if we have a flush, we set that flag low, meaning we shouldn't push 
// 

circular_queue #(.SS(SS), .IN_WIDTH(SS), .SEL_IN(SS), .SEL_OUT(1), .DEPTH(ROB_DEPTH)) instruction_queue
                (.clk(clk), .rst(rst || flush),
                 .full(inst_queue_full), .in(decoded_inst),
                 .out(instruction), .flush(flush),
                 .push(valid_request), .pop(pop_inst_q), .empty(inst_q_empty),
                 .out_bitmask('1), .in_bitmask(d_bitmask), .tail_out(inst_tail),
                 .reg_out(view_inst_tail),
                 .extendo_tail_in('0), .extendo_head_in('0),
                 .reg_select_in(d_reg_sel), .reg_select_out(sel_out_inst), .reg_in(d_reg_in)
                 );
                // planning on passing dummy shit or 0 into reg_select shit

///////////////////// INSTRUCTION FETCH (SIMILAR TO MP2) /////////////////////
super_dispatch_t rs_rob_entry [SS], rob_entries_to_commit [SS];
fetch_stage #(.SS(SS)) fetch_stage_i (
    .clk(clk),
    .rst(rst),
    .predict_branch('0), // Change this later
    .stall_inst(inst_queue_full), 
    .imem_resp(imem_resp), 
    .rob_entries_to_commit(rob_entries_to_commit), // passing branch target from rob
    .pc_reg(pc_reg),
    .imem_rmask(imem_rmask),
    .imem_addr(imem_addr), 
    .decoded_inst(decoded_inst), 
    .valid_request(valid_request), 
    .rob_entries_to_commit1(rob_entries_to_commit1)
);


    // P.S. soumil u r slow


cdb_t cdb;
fu_output_t alu_cmp_output [N_ALU], mul_output [N_MUL];
// Merge cdb 
// ALU entries come first, then MUL, then LSQ last
always_comb begin
    for(int i = 0; i < CDB; i++) begin
        if(i < N_ALU)
            cdb[i] = alu_cmp_output[i];
        else if(i < N_ALU + N_MUL)
            cdb[i] = mul_output [i - N_ALU];
    end
end

// Cycle 0: 
///////////////////// Rename/Dispatch: Physical Register File /////////////////////
// MODULE INPUTS DECLARATION 
physical_reg_request_t dispatch_request[SS];
physical_reg_request_t alu_request [N_ALU] , mul_request [N_MUL];


// INPUTS FROM THE RESERVATION TABLE FROM THE ALU
// @TYLER HOOK THIS UP ----> its hooked up now - <Gay

// MODULE OUTPUT DECLARATION
physical_reg_response_t dispatch_reg_data [SS];
physical_reg_response_t alu_reg_data [N_ALU], mul_reg_data [N_MUL];

// MODULE INSTANTIATION
phys_reg_file #(.SS(SS), .TABLE_ENTRIES(TABLE_ENTRIES)) reg_file (
                .clk(clk), .rst(rst), .regf_we('1), 
                .cdb(cdb),
                .dispatch_request(dispatch_request), .dispatch_reg_data(dispatch_reg_data), 
                .alu_request(alu_request), .alu_reg_data(alu_reg_data),
                .mul_request(mul_request), .mul_reg_data(mul_reg_data)
                ); 

// Cycle 0: 
///////////////////// Rename/Dispatch: Dispatcher /////////////////////

// MODULE INPUTS DECLARATION 
logic rs_full; 
logic rob_full;

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
logic update_rat;

// MODULE INSTANTIATION
dispatcher #(.SS(SS), .PR_ENTRIES(PR_ENTRIES), .ROB_DEPTH(ROB_DEPTH)) dispatcher_i(
             .clk(clk), .rst(rst), 
             .pop_inst_q(pop_inst_q), // Needs to connect to free list as well
             .avail_inst(avail_inst),
             
             .rs_full('0), // Resevation station informs that must stall pipeline (stop requesting pops)
             .inst_q_empty(inst_q_empty), // to prevent pop requests to free list
             .rob_full(rob_full),
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
             
             .rs_rob_entry(rs_rob_entry),
             .update_rat(update_rat)
            ); 


// Cycle 0: 
///////////////////// Rename/Dispatch: RAT + RRAT /////////////////////
// MODULE INPUTS DECLARATION 
logic pop_from_rob;
logic push_to_free_list;
logic [5:0] retire_to_free_list [SS];

logic [5:0] backup_retired_rat [32];

// MODULE OUTPUT DECLARATION

// MODULE INSTANTIATION
rat #(.SS(SS)) rt(.clk(clk), .rst(rst), .regf_we(update_rat), // Need to connect write enable to pop_inst_q?
     .rat_rd(rat_rd),
     .isa_rd(isa_rd), .isa_rs1(isa_rs1), .isa_rs2(isa_rs2),
     .rat_rs1(rat_rs1) , .rat_rs2(rat_rs2),
     .flush(flush),
     .retired_rat_backup(backup_retired_rat)
     );

retired_rat #(.SS(SS)) retire_ratatoullie(
    .clk(clk), .rst(rst),
    .retire_we(pop_from_rob),
    .free_list_entry(retire_to_free_list),
    .rob_info(rob_entries_to_commit),
    .push_to_free_list(push_to_free_list),
    .backup_retired_rat(backup_retired_rat)
    );


// Cycle 0: 
///////////////////// Rename/Dispatch: Free Lists /////////////////////
// MODULE INPUTS DECLARATION 
// MODULE OUTPUT DECLARATION

// MODULE INSTANTIATION
// Dummy free list assigns
logic [$clog2(32)-1:0] d_free_reg_sel [SS];
logic [5:0] d_free_reg_in [SS];
always_comb begin
    for(int i = 0; i < SS; i++) begin
        d_free_reg_sel[i] = '0;
        d_free_reg_in[i] = '0;
    end
end


logic [5:0] backup_freelist [32];
logic [5:0] dummy_backup_freelist [32];
logic [$clog2(32)-1:0] d_backup_reg_sel [32];

logic [$clog2(32):0] tail_backup, head_backup;
logic [$clog2(32)-1:0] select_backup_freelist [32];

always_comb begin
    for (int i = 0; i < 32; i++) begin
        select_backup_freelist[i] = ($clog2(32))'(i);
        d_backup_reg_sel[i] = '0;
    end
end

// free list 
circular_queue #( .SS(SS), .SEL_IN(32), .SEL_OUT(SS), .QUEUE_TYPE(logic [5:0]), .INIT_TYPE(FREE_LIST), .DEPTH(32))
      free_list(.clk(clk), .rst(rst), .in(retire_to_free_list), .push(push_to_free_list), .pop(pop_inst_q),
      .flush(flush),
      .reg_in(backup_freelist), .reg_select_in(d_backup_reg_sel), .reg_select_out(d_free_reg_sel),      
      .out_bitmask(d_bitmask), .in_bitmask('0),
      .extendo_tail_in(tail_backup), .extendo_head_in(head_backup),
      // outputs
      .empty(), .full(), 
      .head_out(), .tail_out(),  
      .out(free_rat_rds), 
      .reg_out()
);



// back up freelist
circular_queue #( .SS(SS), .SEL_IN(SS), .SEL_OUT(32), .QUEUE_TYPE(logic [5:0]), .INIT_TYPE(BACKUP_FREE_LIST), .DEPTH(32))
      backup_free_list(.clk(clk), .rst(rst), .in(retire_to_free_list), .push(push_to_free_list), .pop(push_to_free_list),
      .flush(flush),
      .reg_in(d_free_reg_in), .reg_select_in(d_free_reg_sel), .reg_select_out(select_backup_freelist),      
      .out_bitmask('1), .in_bitmask(d_bitmask),
      .extendo_tail_in('0), .extendo_head_in('0),
      // outputs
      .empty(), .full(), 
      .extendo_head_out(head_backup), .extendo_tail_out(tail_backup),
      .reg_out(backup_freelist)
    );

    
// Cycle 0: 
///////////////////// Rename/Dispatch: ROB /////////////////////
// MODULE INPUTS DECLARATION 

// MODULE OUTPUT DECLARATION

// MODULE INSTANTIATION
rob #(.SS(SS), .ROB_DEPTH(ROB_DEPTH)) rb(.clk(clk), .rst(rst), 
                                         .avail_inst(avail_inst), .dispatch_info(rs_rob_entry), 
                                         .cdb(cdb),
                                         .flush(flush),
                                         .rob_id_next(rob_id_next), 
                                         .rob_entries_to_commit(rob_entries_to_commit),
                                         .rob_full(rob_full),
                                         .pop_from_rob(pop_from_rob), 
                                         .rob_entries_to_commit1(rob_entries_to_commit1)
                                        );

// Cycle 1: 
///////////////////// Issue: ALU Reservation Station /////////////////////
// MODULE INPUTS DECLARATION 

// MODULE OUTPUT DECLARATION

fu_input_t inst_for_fu_alu [N_ALU]; 
logic alu_table_full; 
logic FU_ready_alu [N_ALU];
always_comb begin
    for(int i = 0; i < N_ALU; i++) begin
        FU_ready_alu[i] = 1'b1;
    end
end


// MODULE INSTANTIATION
reservation_table #(.SS(SS), .REQUEST(N_ALU), .TABLE_TYPE(ALU_T), .reservation_table_size(reservation_table_size), 
    .ROB_DEPTH(ROB_DEPTH)) alu_table(.clk(clk), .rst(rst || flush),
                                        .dispatched(rs_rob_entry), // Dispatched shit
                                        .avail_inst(avail_inst), // Thing
                                        .cdb_rob_ids(cdb), // CDB 
                                        .inst_for_fu(inst_for_fu_alu), // send instruction to be caluclated to fu
                                        .fu_request(alu_request), // get vars from phys reg file
                                        .FU_Ready(FU_ready_alu), // ALU FU will never be full 
                                        .table_full(alu_table_full) // Signal that the res table full 
                                        );                
                                        

// Cycle 2: 
///////////////////// Execute:  FU:ALU /////////////////////
// MODULE INPUTS DECLARATION 
// MODULE OUTPUT DECLARATION
                                        
// MODULE INSTANTIATION             

generate
for(genvar i = 0; i < N_ALU; i++) begin : fu_alus
    fu_wrapper fuck_u(
            .clk(clk), .rst(rst),
            .to_be_calculated(inst_for_fu_alu[i]),
            .alu_cmp_output(alu_cmp_output[i]),
            .fu_reg_data(alu_reg_data[i]), .flush(flush)
        ); 
end
endgenerate


// Cycle 1: 
///////////////////// Issue: MULT Reservation Station /////////////////////
// MODULE INPUTS DECLARATION 
logic FU_ready [N_MUL];

// MODULE OUTPUT DECLARATION
fu_input_t inst_for_fu_mult [N_MUL]; 
logic mult_table_full; 


// MODULE INSTANTIATION
reservation_table #(.SS(SS), .REQUEST(N_MUL), .reservation_table_size(reservation_table_size), 
        .ROB_DEPTH(ROB_DEPTH), .TABLE_TYPE(MUL_T)) mult_table(.clk(clk), .rst(rst),
                                                            .dispatched(rs_rob_entry), // Dispatched shit
                                                            .avail_inst(avail_inst), // Thing
                                                            .cdb_rob_ids(cdb), // CDB 
                                                            .inst_for_fu(inst_for_fu_mult), // send instruction to be caluclated to fu
                                                            .fu_request(mul_request), // get vars from phys reg file
                                                            .FU_Ready(FU_ready), // ALU FU will never be full 
                                                            .table_full(mult_table_full) // Signal that the res table full 
                                                            );                
                                        

// Cycle 2: 
///////////////////// Execute: FU - MULT /////////////////////
// MODULE INPUTS DECLARATION 
// MODULE OUTPUT DECLARATION
                                        
// MODULE INSTANTIATION             

generate
for(genvar i = 0; i < N_MUL; i++) begin : fu_muls
    fu_wrapper_mult fuck_mu(
            .clk(clk),.rst(rst || flush),
            .to_be_multiplied(inst_for_fu_mult[i]),
            .mul_output(mul_output[i]),
            .FU_ready(FU_ready[i]),
            .fu_reg_data(mul_reg_data[i])
        ); 
end
endgenerate

// Temporary:
assign dmem_rmask = 1'b0;
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
