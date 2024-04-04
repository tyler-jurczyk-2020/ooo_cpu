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

        // inform instruction queue to pop another instruction 
        output logic pop_inst_from_q; 
        // This is based on whether the reservation station is full or not
        input logic rs_full; 

        // instruction input from the instruction queue
        input instruction_info_reg_t inst [SS], 

        // Acquire RAT Mapping
        output 
        
    ); 



    
    endmodule : rename_dispatch
    