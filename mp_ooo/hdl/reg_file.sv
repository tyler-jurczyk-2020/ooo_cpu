// wus up
module reg_file
import rv32i_types::*;
(
    input   logic           clk,
    input   logic           rst,
    input   logic           regf_we,

    // Physical register
    input   logic   [31:0]  rd_v [2],
    input   logic   [6:0]   rd_s [2], rs1_s [2], rs2_s [2],
    output  logic   [31:0]  rs1_v [2], rs2_v [2]
);

    logic   [31:0]  data [64];

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < 32; i++) begin
                data[i] <= '0;
            end
        end else if (regf_we && (rd_s != 5'd0)) begin
            for (int i = 0; i < 2; i++)
                data[rd_s] <= rd_v[i];
        end
    end

    always_comb begin
        for (int i = 0; i < 2; i++) begin
            rs1_v[i] = (rs1_s[i] != 5'd0) ? data[rs1_s[i]] : '0;
            rs2_v[i] = (rs2_s[i] != 5'd0) ? data[rs2_s[i]] : '0;
        end
    end
endmodule : reg_file
