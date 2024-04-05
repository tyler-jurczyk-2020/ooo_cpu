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
    input super_dispatch_t rob_info [SS],

////// OUTPUTS:
    output logic [5:0] free_list_entry [SS],
    output logic push_to_free_list
);

logic [5:0] data [32]; // array of rats in the retired rat state

// NOT CORRECT FOR SS > 1 !!!
assign push_to_free_list = retire_we && rob_info[0].inst.rd_s;

always_ff @(posedge clk) begin
    for(int i = 0; i < SS; i++) begin
        if (rst) begin
            // reset all the mfing entries
            for(int i = 0; i < 32; i++) 
                data[i] = i[5:0];
        end
        else if(retire_we && rob_info[i].inst.rd_s != 5'b0) begin
            // update retired rat based on instr's reg mapping
            data[rob_info[i].inst.rd_s] <= rob_info[i].rat.rd;
        end
    end
end

always_comb begin
    for(int i = 0; i < SS; i++) begin
        if(retire_we && rob_info[i].inst.rd_s != 5'b0)
            free_list_entry[i] = data[rob_info[i].inst.rd_s];
        else
            free_list_entry[i] = 'x;
    end
end

endmodule : retired_rat
