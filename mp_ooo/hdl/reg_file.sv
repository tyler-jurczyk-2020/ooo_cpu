// soumil is slow
// watch the fucking lectures u actual cocksucker -SG
module reg_file
import rv32i_types::*;
#(
    parameter SS = 2, // Superscalar 
    parameter ROB_DEPTH = 7
)
(
    input   logic           clk,
    input   logic           rst,
    input   logic           regf_we,

    // Physical registers
    // Values to write into registers
    input logic [31:0] rd_v [SS], 
    // Physical Destination Register (To Write To)
    input logic [6:0] rd_s [SS],
    // Associated ROB 
    input logic [ROB_DEPTH-1:0] ROB_ID [SS], 
    // Physical Source Registers to read data from 
    input logic [6:0] rs1_s [SS], 
    input logic [6:0] rs2_s [SS], 
    
    output  logic   [31:0]  rs1_v [SS], rs2_v [SS]
);

    logic   [31:0]  data [64];

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < 32; i++) begin
                data[i] <= '0;
            end
        end else if (regf_we) begin
            for (int i = 0; i < SS; i++) begin
                if(rd_s[i] != 5'b0)
                    data[rd_s[i]] <= rd_v[i];
            end
        end
    end

    always_comb begin
        for (int i = 0; i < SS; i++) begin
            rs1_v[i] = (rs1_s[i] != 5'd0) ? data[rs1_s[i]] : '0;
            rs2_v[i] = (rs2_s[i] != 5'd0) ? data[rs2_s[i]] : '0;
        end
    end
endmodule : reg_file
