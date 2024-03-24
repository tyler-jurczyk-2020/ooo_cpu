module circular_queue
#(
    parameter WIDTH = 32,
    parameter DEPTH = 16,
    parameter DEPTH_BITS = 4, 
    parameter SUPERSCALAR = 4,
    parameter SUPERSCALAR_BITS = 2,
)(
    input logic clk, rst,
    input logic push, pop, 
    input logic [SUPERSCALAR_BITS-1:0] amount,
    input logic [WIDTH-1:0] in [SUPERSCALAR], // Values pushed in
    input logic [WIDTH-1:0] reg_in [SUPERSCALAR], // Values used to modify entries
    input logic [DEPTH_BITS-1:0] reg_select_in [SUPERSCALAR], reg_select_out [SUPERSCALAR],
    input logic [SUPERSCALAR-1:0] in_bitmask, out_bitmask

    output logic full,
    output logic [WIDTH-1:0] out [SUPERSCALAR],
    output logic [WIDTH-1:0] reg_out [SUPERSCALAR]
);

logic [WIDTH-1:0] entries [DEPTH];
logic [DEPTH_BITS:0] head, tail; // One bit to differentiate between full/empty

assign full = (head[DEPTH_BITS-1:0] == tail[DEPTH_BITS]) && (head[DEPTH_BITS] != tail[DEPTH_BITS]);

always_ff begin
    if(rst) begin
        head <= 0;
        tail <= 0;
        for(int i = 0; i < DEPTH; i++) begin
            entries[i] <= 0;
        end
        for(int i = 0; i < SUPERSCALAR; i++) begin
            reg_out[i] = 0;
        end
    end
    else begin
        if(push) begin
            head <= head + amount;
            for(int i = head; i >= head - amount; i--) begin
                entries[i] <= in[i];
            end
        end
        else if(pop) 
            tail <= tail + amount;

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
