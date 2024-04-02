// rename/dispatch shit
module rename_dispatch
import rv32i_types::*;
#(
    parameter SS = 2,
    parameter PR_ENTRIES = 64,
    parameter ROB_DEPTH = 8
)
(
    input logic clk, 
    input logic rst,
    
    // popped instruction(s)
    input logic inst_q_empty,
    output logic pop_inst_q, avail_inst,
    input instruction_info_reg_t instruction [SS],

    // architectural registers to get renamed passed to RAT
    output   logic   [4:0] isa_rs1 [SS], isa_rs2 [SS], isa_rd [SS],
    output logic [5:0] rat_dest [SS],
    // physical registers from RAT
    input  logic  [5:0]  rat_rs1 [SS], rat_rs2 [SS],

    // Get a value from the Free List for Destination Register
    input [5:0] free_list_regs [SS], 

    // Get source register dependencies from physical register
    output logic [$clog2(PR_ENTRIES)-1:0] sel_pr_rs1 [SS], sel_pr_rs2 [SS],
    input physical_reg_data_t pr_rs1 [SS], pr_rs2 [SS],

    // Get ROB info
    input logic [$clog2(ROB_DEPTH)-1:0] rob_id_next [SS],
    
    // Reservation station
    input logic rs_full,
    output dispatch_reservation_t rs_entries [SS]
);

logic avail_inst;
always_ff @(posedge clk) begin
    if(rst)
        avail_inst <= 1'b0;
    else
        avail_inst <= pop_inst_q;
end

// Lookup RAT source regs and modify dest reg:
always_comb begin
    if(avail_inst) begin
        // Update RAT
        for(int i = 0; i < SS; i++) begin
            isa_rs1[i] = instruction[i].rs1_s;
            isa_rs2[i] = instruction[i].rs2_s;
            isa_rd[i] = instruction[i].rd_s;
            sel_pr_rs1[i] = rat_rs1[i];
            sel_pr_rs2[i] = rat_rs2[i];
        end
        rat_dest = free_list_regs;
        
        // Setup entries going to reservation station
        for(int i = 0; i < SS; i++) begin
            // ROB Setup
            rs_entries[i].rob.rob_id = rob_id_next[i];
            rs_entries[i].rob.commit = 1'b0;
            rs_entries[i].rob.rs1_source = pr_rs1[i].ROB_ID;
            rs_entries[i].rob.rs2_source = pr_rs2[i].ROB_ID;

            // if we need rs1, then if there is no dependency then input1 is met
            // if we need rs1, then if there is a dependency in waiting then input1 is not met
            // if we don't need rs1, then input1 is met
            if(instruction[i].rs1_needed) begin
                rs_entries[i].rob.input1_met = ~pr_rs1[i].dependency; 
            end
            else begin
                rs_entries[i].rob.input1_met = '1;  
            end
            if(instruction[i].rs2_needed) begin
                rs_entries[i].rob.input2_met = ~pr_rs2[i].dependency; 
            end
            else begin
                rs_entries[i].rob.input2_met = '1;  
            end

            // RVFI Setup
            rs_entries[i].rvfi.valid = instruction[i].valid;
            rs_entries[i].rvfi.order = 'x; // Determine order in ROB 
            rs_entries[i].rvfi.inst = instruction[i].inst;
            rs_entries[i].rvfi.rs1_addr = instruction[i].rs1_s;
            rs_entries[i].rvfi.rs2_addr = instruction[i].rs2_s;
            rs_entries[i].rvfi.rs1_rdata = 'x;
            rs_entries[i].rvfi.rs2_rdata = 'x;
            rs_entries[i].rvfi.rd_addr = instruction[i].rd_s;
            rs_entries[i].rvfi.rd_wdata = 'x;
            rs_entries[i].rvfi.pc_rdata = instruction[i].pc_curr;
            rs_entries[i].rvfi.pc_wdata = instruction[i].pc_next;
            rs_entries[i].rvfi.mem_addr = 'x;
            // Need to compute rmask/wmask based on type of mem op
            rs_entries[i].rvfi.mem_rmask = 'x;
            rs_entries[i].rvfi.mem_wmask = 'x;
            rs_entries[i].rvfi.mem_rdata = 'x;
            rs_entries[i].rvfi.mem_wdata = 'x;

            //Instruction setup
            rs_entries[i].inst = instruction[i];

            //Rat Registers
            rs_entries[i].rat.rs1 = rat_rs1[i];
            rs_entries[i].rat.rs2 = rat_rs2[i];
            rs_entries[i].rat.rd = free_list_regs[i];
        end
    end
    else begin
        for(int i = 0; i < SS; i++) begin
            isa_rs1[i] = 'x;
            isa_rs2[i] = 'x;
            isa_rd[i] = 'x;
            rat_dest[i] = 'x;
        end

        // Setup entries going to reservation station
        for(int i = 0; i < SS; i++) begin 
            // ROB Setup
            rs_entries[i].rob.rob_id = 'x;
            rs_entries[i].rob.commit = 'x;
            rs_entries[i].rob.input1_met = 'x;
            rs_entries[i].rob.input2_met = 'x;
            rs_entries[i].rob.rs1_source = 'x;
            rs_entries[i].rob.rs2_source = 'x;
            
            // RVFI setup
            rs_entries[i].rvfi.valid = 'x; // SOUMIL IS SLOW
            rs_entries[i].rvfi.order = 'x; // SOUMIL IS SLOW // Need to put actual order here
            rs_entries[i].rvfi.inst = 'x;
            rs_entries[i].rvfi.rs1_addr = 'x;
            rs_entries[i].rvfi.rs2_addr = 'x;
            rs_entries[i].rvfi.rs1_rdata = 'x;
            rs_entries[i].rvfi.rs2_rdata = 'x;
            rs_entries[i].rvfi.rd_addr = 'x;
            rs_entries[i].rvfi.rd_wdata = 'x;
            rs_entries[i].rvfi.pc_rdata = 'x;
            rs_entries[i].rvfi.pc_wdata = 'x;
            rs_entries[i].rvfi.mem_addr = 'x;
            // Need to compute rmask/wmask based on type of mem op
            rs_entries[i].rvfi.mem_rmask = 'x;
            rs_entries[i].rvfi.mem_wmask = 'x;
            rs_entries[i].rvfi.mem_rdata = 'x;
            rs_entries[i].rvfi.mem_wdata = 'x;

            //Instruction setup
            rs_entries[i].inst = 'x;

            //Rat Registers
            rs_entries[i].rat.rs1 = 'x;
            rs_entries[i].rat.rs2 = 'x;
            rs_entries[i].rat.rd = 'x;
        end
    end
end

// Pop from the free list and read from instruction queue:
assign pop_inst_q = ~inst_q_empty && ~rs_full;

endmodule : rename_dispatch
