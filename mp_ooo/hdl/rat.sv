module rat
import rv32i_types::*;
#(
    parameter SS = 2
)
(
    input   logic           clk,
    input   logic           rst,
    input   logic [1:0]          regf_we,
    input   logic           flush,
    input   logic [5:0]     retired_rat_backup[32],
    // Physical register
    input   logic   [5:0]  rat_rd [SS],
    input   logic   [4:0]  isa_rd [SS], isa_rs1 [SS], isa_rs2 [SS],
    output  logic   [5:0]  rat_rs1 [SS], rat_rs2 [SS]
);

// MSB is valid bit
logic   [5:0] data [32];


always_ff @(posedge clk) begin
    if (rst) begin
        for (int unsigned i = 0; i < 32; i++) begin
            data[i] <= 6'(i);
        end
    end
    
    else if (flush) begin
        data <= retired_rat_backup;
    end
    else begin
        if (regf_we[0]) begin
            data[isa_rd[0]] <= rat_rd[0];
        end
        if(regf_we[1]) begin
            data[isa_rd[1]] <= rat_rd[1];
        end
    end
end

always_comb begin
    for(int i = 0; i < SS; i++) begin
        rat_rs1[i] = (isa_rs1[i] != 5'd0) ? data[isa_rs1[i]][5:0] : '0;
        rat_rs2[i] = (isa_rs2[i] != 5'd0) ? data[isa_rs2[i]][5:0] : '0;
    end
end

// j is cringe

endmodule : rat
