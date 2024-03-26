module circular_queue
import rv32i_types::*;
#(
    parameter WIDTH = 32,
    parameter DEPTH = 4,
    parameter DEPTH_BITS = 2 
)(
    input logic clk, rst,
    input logic push, pop, 
    input logic [WIDTH-1:0] in [2], // Values pushed in
    input logic [WIDTH-1:0] reg_in [2], // Values used to modify entries
    input logic [DEPTH_BITS-1:0] reg_select_in [2], reg_select_out [2],
    input logic [1:0] in_bitmask, out_bitmask,

    // Need to consider potentially how partial pushes/pops may work in superscalar context
    output logic empty,
    output logic full,
    output logic [WIDTH-1:0] out [2], // Values pushed out
    output logic [WIDTH-1:0] reg_out [2] // Values selected to be observed
);

logic [WIDTH-1:0] entries [DEPTH];
logic [DEPTH_BITS:0] head, tail, head_next, tail_next; // One bit to differentiate between full/empty
logic [31:0] sext_head, sext_tail, sext_amount;

assign full = (head[DEPTH_BITS-1:0] == tail[DEPTH_BITS-1:0]) && (head[DEPTH_BITS] != tail[DEPTH_BITS]);
assign empty = (head == tail);

assign sext_head = {{(32-DEPTH_BITS-1){1'b0}}, head[DEPTH_BITS-1:0]}; // Excludes top bit so queue is indexed properly
assign sext_tail = {{(32-DEPTH_BITS-1){1'b0}}, tail[DEPTH_BITS-1:0]};
assign sext_amount = 32'h2;

assign head_next = head + {{(DEPTH_BITS-1){1'b0}}, 2'h2};
assign tail_next = tail + {{(DEPTH_BITS-1){1'b0}}, 2'h2};

always_ff @(posedge clk) begin
    if(rst) begin
        head <= '0;
        tail <= '0;
        for(int i = 0; i < DEPTH; i++) begin
            entries[i] <= '0;
        end
        for(int i = 0; i < 2; i++) begin
            reg_out[i] <= '0;
        end
    end
    else begin
        if(push) begin
            head <= head_next;
            for(int i = 0; i < DEPTH; i++) begin
                if(unsigned'(i) < sext_head + sext_amount && unsigned'(i) >= sext_head) begin
                    entries[unsigned'(i)] <= in[unsigned'(i) - sext_head];
                end
            end
        end
        else if(pop)  begin
            tail <= tail_next;
            for(int i = 0; i < DEPTH; i++) begin
                if(unsigned'(i) < sext_tail + sext_amount && unsigned'(i) >= sext_tail)
                    out[unsigned'(i) - sext_tail] <= entries[unsigned'(i)];
            end
        end

        for(int i = 0; i < 2; i++) begin
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
