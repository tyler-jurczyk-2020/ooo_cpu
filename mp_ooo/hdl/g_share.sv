module gshare #( //
    // size of Global History Register
    parameter GHR_SIZE = 10,      
    // entry size of Pattern History Table
    parameter PHT_ENTRIES = 1024   
)
(
    // rst & clk
    input logic rst,
    input logic clk,
    // r we branchin
    input logic branch_taken,
    // target branch addr --> this is the PC value imma xor w/
    input logic [31:0] branch_addr,
    // branch prediction 
    output logic branch_prediction
);

// Global History Register
logic [GHR_SIZE-1:0] ghr;
// Pattern History Table
logic [1:0] pht[PHT_ENTRIES]; 

// PHT mask & index
localparam PHT_MASK = 10'b1111111111; // pht mask --> 1111111111
logic [GHR_SIZE-1:0] pht_index; 

// init & update brrrrrrrrrrrrrrt
always_ff @(posedge clk)begin
    // init ghr & pht on reset
    if(rst) begin
        // init ghr
        ghr <= '0;

        // init pht --> bitch ass not taken:(01)
        for(int i = 0; i < PHT_ENTRIES; i++) begin
            pht[i] <= 2'b01;
        end
    end

    // update both register tables
    else begin
        // update ghr, ghr hashed w/ branch hit
        ghr <= {ghr[GHR_SIZE-2:0], branch_taken};

        // update pht, based on branch outcome
        pht_index <= (branch_addr[GHR_SIZE-1:0] ^ ghr) & PHT_MASK; // declarin this shit here to avoid timing mismatch
        
        if(branch_taken) begin
            if (pht[pht_index] < 2'b11)
                pht[pht_index] <= pht[pht_index] + 2'd1;
        end
        else begin
            if(pht[pht_index] > 2'b00)
                pht[pht_index] <= pht[pht_index] - 2'd1;
        end
    end
end


// branch pred based on msb of counter
assign branch_prediction = pht[pht_index][1];

endmodule : gshare
