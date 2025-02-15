module rat
import rv32i_types::*;
#(
    parameter SS = 2
)
(
    input   logic           clk,
    input   logic           rst,
    input   logic           regf_we,
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
    
    else if (regf_we) begin
        for (int i = 0; i < SS; i++) begin
            if(isa_rd[i] != 5'd0)
                data[isa_rd[i]] <= rat_rd[i];
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
