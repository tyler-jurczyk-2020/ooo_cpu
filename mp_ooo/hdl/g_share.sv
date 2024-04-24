module gshare #(
    // size of Global Branch History
    parameter GBR_SIZE = 10,      
    // entry size of Pattern History Table
    parameter PHT_ENTRIES = 1024   
)
(
    // rst & clk
    input logic rst,
    input logic clk,
    // r we takin a branch
    input logic branch_taken,
    // target branch addr
    input logic [31:0] branch_addr,
    // actual branch prediction
    output logic branch_prediction
);

// Global Branch History
logic [GBR_SIZE-1:0] gbr;
// Pattern History Table
logic [1:0] pht[PHT_ENTRIES]; 

// PHT mask & index
localparam PHT_MASK = PHT_ENTRIES - 1; // pht mask --> 1111111111
logic [clog2$(GBR_SIZE)-1:0] pht_index; 

// init & update brrrrrrrrrrrrrrt
always_ff @(posedge clk)begin
    // init gbr & pht on reset
    if(rst) begin
        // init gbr
        gbr <= '0;
        // init pht --> bitch ass not taken:(01)
        for(int i = 0; i < PHT_ENTRIES; i++)
            pht[i] <= 2'b01;
    end

    // update both register tables
    else begin
        // update gbr, regardless of branch condition
        gbr <= (gbr << 1) | branch_taken;
        // update pht, based on branch outcome
        pht_index = (branch_addr[GBR_SIZE-1:0] ^ gbr) & PHT_MASK;
        if(branch_taken) begin
            if (pht[pht_index] < 2'b11)
                pht[pht_index] <= pht[pht_index] + 1;
        end
        else begin
            if(pht[pht_index] > 2'b00)
                pht[pht_index] <= pht[pht_index] - 1;
        end
    end
end

// actual prediction
always_comb begin
    // branch pred based on msb of counter
    branch_prediction = pht[(branch_addr[GBR_SIZE-1:0] ^ gbr) & PHT_MASK][1];
end
endmodule : gshare
