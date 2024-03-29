module dispatcher
    import rv32i_types::*;
    #(
        parameter SS = 2
        parameter ROB_DEPTH = 8
    )
    (   
        input logic clk, 
        input logic rst,
        
        // Flag that new data is coming in to be dispatched
        input logic pop_inst_q, 
        // popped instruction(s)
        input instruction_info_reg_t instruction [SS];

        // architectural registers to get renamed passed to RAT
        output   logic   isa_rs1 [SS], isa_rs2 [SS],
        // physical registers from RAT
        input  logic   [5:0]  rat_rs1 [SS], rat_rs2 [SS], 

        // Get a value from the Free List for EBR
        output pop_free_list, 
        input [5:0] free_list_regs [SS], 

        // Get source register dependencies from physical register
        input physical_reg_data_t pir_rs1 [SS], pir_rs2 [SS]
        
        output rob_t rob_entry, 
        output reservation_station_t reserevation_entry
    );

    // set up rvfi struct
    rvfi_t rvfi; 

    always_comb begin
        for(int i = 0; i < SS; i++) begin
            // RVFI setup
            rvfi.valid = instruction[i].valid;
            rvfi.order = 64'b0; // Need to put actual order here
            rvfi.inst = instruction[i].inst;
            rvfi.rs1_addr = instruction[i].rs1_s;
            rvfi.rs2_addr = instruction[i].rs2_s;
            rvfi.rs1_rdata = 'x;
            rvfi.rs2_rdata = 'x;
            rvfi.rd_addr = instruction[i].rd_s;
            rvfi.rd_wdata = 'x;
            rvfi.pc_rdata = instruction[i].pc_curr;
            rvfi.pc_wdata = instruction[i].pc_next;
            rvfi.mem_addr = 'x;
            // Need to compute rmask/wmask based on type of mem op
            rvfi.mem_rmask = 'x;
            rvfi.mem_wmask = 'x;
            rvfi.mem_rdata = 'x;
            rvfi.mem_wdata = 'x;

            //Instruction setup
            inst = instruction[i];
        end
    end


    // Get the free register

    // 

   
    
    endmodule : dispatcher
