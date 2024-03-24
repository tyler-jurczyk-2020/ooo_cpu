module circular_queue
#(
    parameter WIDTH = 32,
    parameter DEPTH = 16,
    parameter DEPTH_BITS = 4, 
    parameter SUPERSCALAR = 4,
    parameter SUPERSCALAR_BITS = 2
)(
    input logic clk, rst,
    input logic push, pop, 
    input logic [SUPERSCALAR_BITS-1:0] amount,
    input logic [WIDTH-1:0] in [SUPERSCALAR], // Values pushed in
    input logic [WIDTH-1:0] reg_in [SUPERSCALAR], // Values used to modify entries
    input logic [DEPTH_BITS-1:0] reg_select_in [SUPERSCALAR], reg_select_out [SUPERSCALAR],
    input logic [SUPERSCALAR-1:0] in_bitmask, out_bitmask,

    // Need to consider potentially how partial pushes/pops may work in superscalar context
    output logic empty,
    output logic full,
    output logic [WIDTH-1:0] out [SUPERSCALAR], // Values pushed out
    output logic [WIDTH-1:0] reg_out [SUPERSCALAR] // Values selected to be observed
);

logic [WIDTH-1:0] entries [DEPTH];
logic [DEPTH_BITS:0] head, tail; // One bit to differentiate between full/empty
logic [31:0] sext_head, sext_tail, sext_amount;

assign full = (head[DEPTH_BITS-1:0] == tail[DEPTH_BITS-1:0]) && (head[DEPTH_BITS] != tail[DEPTH_BITS]);
assign empty = (head == tail);

assign sext_head = {{(32-DEPTH_BITS-1){1'b0}}, head};
assign sext_tail = {{(32-DEPTH_BITS-1){1'b0}}, tail};
assign sext_amount = {{(32-SUPERSCALAR_BITS){1'b0}}, amount};

always_ff @(posedge clk) begin
    if(rst) begin
        head <= 0;
        tail <= 0;
        for(int i = 0; i < DEPTH; i++) begin
            entries[i] <= 0;
        end
        for(int i = 0; i < SUPERSCALAR; i++) begin
            reg_out[i] <= 0;
        end
    end
    else begin
        if(push) begin
            head <= head + {{(DEPTH_BITS-SUPERSCALAR_BITS+1){1'b0}}, amount};
            for(int i = 0; i < DEPTH; i++) begin
                if(i <= sext_head && i > sext_head - sext_amount)
                    entries[i] <= in[sext_head - i];
            end
        end
        else if(pop)  begin
            tail <= tail + {{(DEPTH_BITS-SUPERSCALAR_BITS+1){1'b0}}, amount};
            for(int i = 0; i < DEPTH; i++) begin
                if(i <= sext_tail && i > sext_tail - sext_amount)
                    out[i] <= entries[sext_tail - i];
            end
        end

        for(int i = 0; i < SUPERSCALAR; i++) begin
            if(in_bitmask[i])
                entries[reg_select_in[i]] <= reg_in[i];

            if(out_bitmask[i])
                reg_out[i] <= entries[reg_select_out[i]];
            else
                reg_out[i] <= 'x;
        end
    end
end

endmodule : circular_queue
