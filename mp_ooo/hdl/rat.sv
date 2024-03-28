// wus up
module rat
import rv32i_types::*;
(
    input   logic           clk,
    input   logic           rst,
    input   logic           regf_we,

    // Physical register
    input   logic   [5:0]  rat_rd [2],
    input   logic   [4:0]  isa_rd [2], isa_rs1 [2], isa_rs2 [2],
    output  logic   [5:0]  rat_rs1 [2], rat_rs2 [2]
);

// MSB is valid bit
logic   [6:0] data [32];

always_ff @(posedge clk) begin
    if (rst) begin
        for (int i = 0; i < 32; i++)
            data[i] <= '0;
    end

    else if (regf_we && (isa_rd != 5'd0)) begin
        for (int i = 0; i < 2; i++)
            data[isa_rd[i]] <= {1'b1, rat_rd[i]};
    end
end

always_comb begin
    for(int i = 0; i < 2; i++) begin
        rat_rs1[i] = (isa_rs1[i] != 5'd0) ? data[isa_rs1[i]][5:0] : '0;
        rat_rs2[i] = (isa_rs2[i] != 5'd0) ? data[isa_rs1[i]][5:0] : '0;
    end
end

// j is cringe

endmodule : rat
