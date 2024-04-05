// rename/dispatch shit
module dispatcher
    import rv32i_types::*;
    #(
        parameter SS = 2,
        parameter PR_ENTRIES = 64,
        parameter ROB_DEPTH = 8
    )
    (
        input logic clk, 
        input logic rst,

        // inform inst queue to pop another inst 
        output logic pop_inst_q, 
        output logic avail_inst, 
        // This is based on whether the reservation station is full or not
        input logic rs_full, 
        input logic inst_q_empty, 

        // inst input from the inst queue
        input instruction_info_reg_t inst [SS], 

        // Acquire RAT Mapping
        output logic [4:0] isa_rs1 [SS], 
        output logic [4:0] isa_rs2 [SS], 
        // Width of the phys. reg. is larger because we're supporting twice 
        // as many internal phys. reg as arch. reg. 
        input logic [5:0] rat_rs1 [SS], 
        input logic [5:0] rat_rs2 [SS], 

        // Phys Reg to Update Mapping for
        output logic [4:0] isa_rd[SS],
        // New Phys RD for ISA RD
        output logic [5:0] rat_rd[SS],

        // Acquire new mapping for destination register 
        // Free list is popped same time that the inst queue is popped
        input logic [5:0] free_rat_rds [SS], 

        // Physical register ports 
        output physical_reg_request_t dispatch_request [SS],
        input physical_reg_response_t dispatch_reg_data [SS],

        // Acquire ROB_ID for current inst. 
        // This will be useful for updating the reservation station later
        input logic [$clog2(ROB_DEPTH)-1:0] rob_id_next [SS],
        
        // Build a super dispatch struct to feed into the ROB and the Reservation Station
        output super_dispatch_t rs_rob_entry [SS]
    ); 

    // We want to gain new input every clock cycle from the free list and inst queues
    // unless we need to stall because of backlog in the reservation station 
    // Because this signal will drive popping from two queues, ensure that if the inst. queue is 
    // empty, then we don't still pop from the free list queue
    // We latch this signal because we want this signal to be 0 when rst is high
    always_ff @ (posedge clk) begin
        if(rst) begin
            avail_inst <= '0; 
        end
        else begin
            avail_inst <= pop_inst_q; 
        end
    end

    assign pop_inst_q = ~rs_full && ~inst_q_empty; 
    
    always_comb begin
        if(pop_inst_q) begin
            // need to build rat signals, rvfi signals

            for(int i = 0; i < SS; i++) begin
                // Get the ISA Regs to read
                isa_rs1[i] = inst[i].rs1_s;
                isa_rs2[i] = inst[i].rs2_s;
                // Set the RAT Entry whose mapping to update with free list
                isa_rd[i] = inst[i].rd_s;
                rat_rd[i] = free_rat_rds[i];
                // Set the inputs to the phys. reg. file that we would like to read
                // We get the phys. eg. to read from by the RAT
                dispatch_request[i].rs1_s = rat_rs1[i];
                dispatch_request[i].rs2_s = rat_rs2[i];
            end

            for(int i = 0; i < SS; i++) begin
                // ROB Setup
                rs_rob_entry[i].rob.rob_id = rob_id_next[i];
                rs_rob_entry[i].rob.commit = 1'b0;
                rs_rob_entry[i].rs_entry.rs1_source = dispatch_reg_data[i].rs1_v.ROB_ID;
                rs_rob_entry[i].rs_entry.rs2_source = dispatch_reg_data[i].rs2_v.ROB_ID;

                if(~inst[i].execute_operand1[0]) begin
                    rs_rob_entry[i].rs_entry.input1_met = ~dispatch_reg_data[i].rs1_v.dependency; 
                end
                else begin
                    rs_rob_entry[i].rs_entry.input1_met = '1;  
                end

                if(~inst[i].execute_operand2[0]) begin
                    rs_rob_entry[i].rs_entry.input2_met = ~dispatch_reg_data[i].rs2_v.dependency; 
                end
                else begin
                    rs_rob_entry[i].rs_entry.input2_met = '1; 
                end

                // RVFI Setup
                rs_rob_entry[i].rvfi.valid = inst[i].valid;
                rs_rob_entry[i].rvfi.order = 'x; // Determine order in ROB 
                rs_rob_entry[i].rvfi.inst = inst[i].inst;
                rs_rob_entry[i].rvfi.rs1_addr = inst[i].rs1_s;
                rs_rob_entry[i].rvfi.rs2_addr = inst[i].rs2_s;
                rs_rob_entry[i].rvfi.rs1_rdata = 'x;
                rs_rob_entry[i].rvfi.rs2_rdata = 'x;
                rs_rob_entry[i].rvfi.rd_addr = inst[i].rd_s;
                rs_rob_entry[i].rvfi.rd_wdata = 'x;
                rs_rob_entry[i].rvfi.pc_rdata = inst[i].pc_curr;
                rs_rob_entry[i].rvfi.pc_wdata = inst[i].pc_next;
                rs_rob_entry[i].rvfi.mem_addr = 'x;
                // Need to compute rmask/wmask based on type of mem op
                // By default we don't make a memory request
                rs_rob_entry[i].rvfi.mem_rmask = 4'b0;
                rs_rob_entry[i].rvfi.mem_wmask = 4'b0;
                rs_rob_entry[i].rvfi.mem_rdata = 'x;
                rs_rob_entry[i].rvfi.mem_wdata = 'x;

                //inst setup
                rs_rob_entry[i].inst = inst[i];

                //Rat Registers
                // If ISA is R0, then since we don't update the RAT we'll always get rat_r = PR0
                // The only issue is we pop a free list reg regardless which could cause problems
                rs_rob_entry[i].rat.rs1 = rat_rs1[i];
                rs_rob_entry[i].rat.rs2 = rat_rs2[i];
                // Don't need to save the mapping we are overwritting because that is in the RRAT
                rs_rob_entry[i].rat.rd = free_rat_rds[i];
            end
        end
        else begin
            for(int i = 0; i < SS; i++) begin
                isa_rs1[i] = 'x;
                isa_rs2[i] = 'x;
                isa_rd[i] = 'x;
                // Set the inputs to the phys. reg. file that we would like to read
                // We get the phys. eg. to read from by the RAT
                dispatch_request[i].rs1_s = 'x; 
                dispatch_request[i].rs2_s = 'x;
            end

            // Setup entries going to reservation station
            for(int i = 0; i < SS; i++) begin 
                // ROB Setup
                rs_rob_entry[i].rob.rob_id = 'x;
                rs_rob_entry[i].rob.commit = 'x;
                rs_rob_entry[i].rs_entry.input1_met = 'x;
                rs_rob_entry[i].rs_entry.input2_met = 'x;
                rs_rob_entry[i].rs_entry.rs1_source = 'x;
                rs_rob_entry[i].rs_entry.rs2_source = 'x;
                
                // RVFI setup
                rs_rob_entry[i].rvfi.valid = 'x; // SOUMIL IS SLOW
                rs_rob_entry[i].rvfi.order = 'x; // SOUMIL IS SLOW // Need to put actual order here
                rs_rob_entry[i].rvfi.inst = 'x;
                rs_rob_entry[i].rvfi.rs1_addr = 'x;
                rs_rob_entry[i].rvfi.rs2_addr = 'x;
                rs_rob_entry[i].rvfi.rs1_rdata = 'x;
                rs_rob_entry[i].rvfi.rs2_rdata = 'x;
                rs_rob_entry[i].rvfi.rd_addr = 'x;
                rs_rob_entry[i].rvfi.rd_wdata = 'x;
                rs_rob_entry[i].rvfi.pc_rdata = 'x;
                rs_rob_entry[i].rvfi.pc_wdata = 'x;
                rs_rob_entry[i].rvfi.mem_addr = 'x;
                // Need to compute rmask/wmask based on type of mem op
                rs_rob_entry[i].rvfi.mem_rmask = 'x;
                rs_rob_entry[i].rvfi.mem_wmask = 'x;
                rs_rob_entry[i].rvfi.mem_rdata = 'x;
                rs_rob_entry[i].rvfi.mem_wdata = 'x;

                //inst setup
                rs_rob_entry[i].inst = 'x;

                //Rat Registers
                rs_rob_entry[i].rat.rs1 = 'x;
                rs_rob_entry[i].rat.rs2 = 'x;
                rs_rob_entry[i].rat.rd = 'x;
            end
        end
    end
    
    endmodule : dispatcher
    