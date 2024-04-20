module circular_queue
import rv32i_types::*;
#(
    type QUEUE_TYPE = instruction_info_reg_t,
    parameter SS = 2,
    parameter IN_WIDTH = SS, 
    parameter SEL_IN = 2,
    parameter SEL_OUT = 2,
    parameter DEPTH = 4
)(
    input logic clk, rst, 
    input logic push, pop,
    input QUEUE_TYPE in [IN_WIDTH], // Values pushed in
    input QUEUE_TYPE reg_in [SEL_IN], // Values used to modify entries
    
    input logic [$clog2(DEPTH)-1:0] reg_select_in [SEL_IN], reg_select_out [SEL_OUT],
    input logic [SEL_IN-1:0] in_bitmask,
    input logic [SEL_OUT-1:0] out_bitmask,
 
    // Need to consider potentially how partial pushes/pops may work in superscalar context
    output logic empty,
    output logic full,
    output logic [$clog2(DEPTH)-1:0] head_out, tail_out,
    output QUEUE_TYPE out [SS], // Values pushed out
    output QUEUE_TYPE reg_out [SEL_OUT] // Values selected to be observed
    );

QUEUE_TYPE entries [DEPTH];
logic [$clog2(DEPTH):0] head, tail, head_next, tail_next, head_spec; // One bit to differentiate between full/empty
logic [31:0] sext_head, sext_tail, sext_amount, sext_amount_in, sext_amount_out;

assign head_out = head[$clog2(DEPTH)-1:0];
assign tail_out = tail[$clog2(DEPTH)-1:0];

assign head_spec = head + SS[$clog2(DEPTH):0]; // Need to make superscalar

assign empty = (head == tail);

assign sext_head = {{(32-$clog2(DEPTH)-1){1'b0}}, head[$clog2(DEPTH)-1:0]}; // Excludes top bit so queue is indexed properly
assign sext_tail = {{(32-$clog2(DEPTH)-1){1'b0}}, tail[$clog2(DEPTH)-1:0]};
assign sext_amount = (2'h1 << (SS - 1));
assign sext_amount_in = 32'(IN_WIDTH);

assign head_next = head + {sext_amount_in[$clog2(DEPTH):0]};
assign tail_next = tail + {sext_amount[$clog2(DEPTH):0]};

logic [$clog2(DEPTH)-1:0]head_lower, tail_lower;
logic head_upper, tail_upper;
assign head_lower = head[$clog2(DEPTH)-1:0];
assign tail_lower = tail[$clog2(DEPTH)-1:0];
assign head_upper = head[$clog2(DEPTH)];
assign tail_upper = tail[$clog2(DEPTH)];

always_comb begin
    if(~push)
        full = (head[$clog2(DEPTH)-1:0] == tail[$clog2(DEPTH)-1:0]) && (head[$clog2(DEPTH)] != tail[$clog2(DEPTH)]);
    else
    // Always use speculative full?
        full = (head_spec[$clog2(DEPTH)-1:0] == tail[$clog2(DEPTH)-1:0]) && (head_spec[$clog2(DEPTH)] != tail[$clog2(DEPTH)]);
end

always_ff @(posedge clk) begin
    if(rst) begin
            head <= '0;
            tail <= '0;
            for(int i = 0; i < DEPTH; i++) 
                entries[i] <= '0;
            for(int i = 0; i < SS; i++)
                out[i] <= '0;
    end
    else begin
        if(push) begin           
            head <= head_next;
            for(int unsigned i = 0; i < DEPTH; i++) begin
                if(i < sext_head + sext_amount_in && i >= sext_head)
                    entries[i] <= in[i - sext_head];
            end
        end
        if(pop)  begin
            tail <= tail_next;
            for(int unsigned i = 0; i < DEPTH; i++) begin
                if(i < sext_tail + sext_amount && i >= sext_tail)
                    out[i - sext_tail] <= entries[i];
            end
        end
        else begin
            for(int i = 0; i < SS; i++)
                out[i] <= 'x;
        end

        for(int i = 0; i < SEL_IN; i++) begin
            if(in_bitmask[i])
                entries[reg_select_in[i]] <= reg_in[i];
        end
    end
end

always_comb begin
    for(int i = 0; i < SEL_OUT; i++) begin
        if(out_bitmask[i])
            reg_out[i] = entries[reg_select_out[i]];
        else
            reg_out[i] = 'x;
    end
end

endmodule : circular_queue
