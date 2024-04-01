module retired_rat
import rv32i_types::*;
#(
    parameter SS = 2
)
(
////// INPUTS:
    input logic clk,
    input logic rst,
    // write enable for Retired Rat
    input logic retire_we, 
    // writing random shit rn
    input rat_t retired_rat_rd [SS], // physical regs for the dest registers of the instrs that are retiring
    input logic [4:0] retired_isa_rd [SS], // ISA reg # bein retired

////// OUTPUTS:
    output rat_t retired_rat_data [32] // array of rats in the retired rat state
)

always_ff @(posedge clk) begin
    if (rst) begin
        // reset all the mfing entries
        for(int i = 0; i < 32; i++) begin
            retired_rat_data[i].rs1 = '0;
            retired_rat_data[i].rs2 = '0;
            retired_rat_data[i].rd = '0;
        end
    end
    else if(retire_we) begin
        // update retired rat based on instr's reg mapping
        for(int i = 0; i < SS; i++) begin
            if(retired_isa_rd[i] != 5'd0)
                retired_rat_data[retired_isa_rd[i]] <= retired_rat_rd[i];
        end
    end
end

endmodule : retired_rat