module circular_queue
import rv32i_types::*;
#(
    type QUEUE_TYPE = instruction_info_reg_t,
    parameter initialization_t INIT_TYPE = ZERO,
    parameter SS = 2,
    parameter DEPTH = 4
)(
    input logic clk, rst, 
    input logic push, pop,
    input QUEUE_TYPE in [SS], // Values pushed in
    input QUEUE_TYPE reg_in [SS], // Values used to modify entries
    input logic [$clog2(DEPTH)-1:0] reg_select_in [SS], reg_select_out [SS],
    input logic [SS-1:0] in_bitmask, out_bitmask,
 
    // Need to consider potentially how partial pushes/pops may work in superscalar context
    output logic empty,
    output logic full,
    output logic [$clog2(DEPTH)-1:0] head_out, tail_out,
    output QUEUE_TYPE out [SS], // Values pushed out
    output QUEUE_TYPE reg_out [SS] // Values selected to be observed
);

QUEUE_TYPE entries [DEPTH];
logic [$clog2(DEPTH):0] head, tail, head_next, tail_next; // One bit to differentiate between full/empty
logic [31:0] sext_head, sext_tail, sext_amount;

assign head_out = head[$clog2(DEPTH)-1:0];
assign tail_out = tail[$clog2(DEPTH)-1:0];

assign full = (head[$clog2(DEPTH)-1:0] == tail[$clog2(DEPTH)-1:0]) && (head[$clog2(DEPTH)] != tail[$clog2(DEPTH)]);
assign empty = (head == tail);

assign sext_head = {{(32-$clog2(DEPTH)-1){1'b0}}, head[$clog2(DEPTH)-1:0]}; // Excludes top bit so queue is indexed properly
assign sext_tail = {{(32-$clog2(DEPTH)-1){1'b0}}, tail[$clog2(DEPTH)-1:0]};
assign sext_amount = (2'h1 << (SS - 1));

assign head_next = head + {{($clog2(DEPTH)-1){1'b0}}, (2'h1 << (SS - 1))};
assign tail_next = tail + {{($clog2(DEPTH)-1){1'b0}}, (2'h1 << (SS - 1))};

always_ff @(posedge clk) begin
    if(rst) begin
        if(INIT_TYPE == ZERO) begin
            head <= '0;
            tail <= '0;
            for(int i = 0; i < DEPTH; i++) 
                entries[i] <= '0;
        end
        if(INIT_TYPE == FREE_LIST) begin
            head <= '0;
            tail <= '0;
            for(int i = 32; i < 32 + DEPTH; i++)
                entries[i-32] <= {{$bits(QUEUE_TYPE)-$clog2(DEPTH){1'b0}}, i[$clog2(DEPTH)-1:0]};
        end
    end
    else begin
        if(push) begin
            head <= head_next;
            for(int i = 0; i < DEPTH; i++) begin
                if(unsigned'(i) < sext_head + sext_amount && unsigned'(i) >= sext_head)
                    entries[unsigned'(i)] <= in[unsigned'(i) - sext_head];
            end
        end
        
        if(pop)  begin
            tail <= tail_next;
            for(int i = 0; i < DEPTH; i++) begin
                if(unsigned'(i) < sext_tail + sext_amount && unsigned'(i) >= sext_tail)
                    out[unsigned'(i) - sext_tail] <= entries[unsigned'(i)];
            end
        end
        else begin
            for(int i = 0; i < SS; i++)
                out[i] <= 'x;
        end

        for(int i = 0; i < SS; i++) begin
            if(in_bitmask[i])
                entries[reg_select_in[i]] <= reg_in[i];
        end
    end
end

always_comb begin
    for(int i = 0; i < SS; i++) begin
        if(out_bitmask[i])
            reg_out[i] = entries[reg_select_out[i]];
        else
            reg_out[i] = 'x;
    end
end

endmodule : circular_queue
