module ls_queue
import rv32i_types::*;
#(
    parameter SS = 2,
    parameter SEL_IN = 2,
    parameter SEL_OUT = 2,
    parameter DEPTH = 4
)(
    input logic clk, rst, 
    input logic push, pop,
    input super_dispatch_t in [SS], // Values pushed in
    input super_dispatch_t reg_in [SEL_IN], // Values used to modify entries
    
    input logic [$clog2(DEPTH)-1:0] reg_select_in [SEL_IN], reg_select_out [SEL_OUT],
    input logic [SEL_IN-1:0] in_bitmask,
    input logic [SEL_OUT-1:0] out_bitmask,
    input logic [31:0] push_amt,
 
    // Need to consider potentially how partial pushes/pops may work in superscalar context
    output logic empty,
    output logic full,
    output logic full_inst,
    output logic [$clog2(DEPTH)-1:0] head_out, tail_out,
    output super_dispatch_t out, // Values pushed out
    output super_dispatch_t reg_out [SEL_OUT] // Values selected to be observed
    );

super_dispatch_t entries [DEPTH];
logic [$clog2(DEPTH):0] head, tail, head_next, tail_next, head_spec; // One bit to differentiate between full/empty
logic [31:0] sext_head, sext_tail, sext_amount, sext_amount_in, sext_amount_out, sext_tail_plus, sext_head_plus;

assign head_out = head[$clog2(DEPTH)-1:0];
assign tail_out = tail[$clog2(DEPTH)-1:0];

assign head_spec = head + SS[$clog2(DEPTH):0]; // Need to make superscalar

assign empty = (head == tail);

assign sext_head = {{(32-$clog2(DEPTH)-1){1'b0}}, head[$clog2(DEPTH)-1:0]}; // Excludes top bit so queue is indexed properly
assign sext_tail = {{(32-$clog2(DEPTH)-1){1'b0}}, tail[$clog2(DEPTH)-1:0]};
assign sext_head_plus = {{(32-$clog2(DEPTH)-1){1'b0}}, head[$clog2(DEPTH)-1:0] + 1'b1};
assign sext_tail_plus = {{(32-$clog2(DEPTH)-1){1'b0}}, tail[$clog2(DEPTH)-1:0] + 1'b1};
assign sext_amount = 2'h1; // Only one output for lsq
assign sext_amount_in = push_amt;

assign head_next = head + {sext_amount_in[$clog2(DEPTH):0]};
assign tail_next = tail + {sext_amount[$clog2(DEPTH):0]};

assign full_inst = (head[$clog2(DEPTH)-1:0] == tail[$clog2(DEPTH)-1:0]) && (head[$clog2(DEPTH)] != tail[$clog2(DEPTH)]);

logic [31:0] counter; 

always_comb begin
    counter = '0; 
    for(int i = 0; i < DEPTH; i++) begin
        if(entries[i].cross_entry.valid) begin
            counter = counter + 1'b1; 
        end
    end

        // Table full spec
    if(counter >= unsigned'(DEPTH - SS - 1)) begin
        full = 1'b1;
    end
    else begin
        full = 1'b0;
    end

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
                if(sext_amount_in == 32'h1) 
                    entries[sext_head] <= in[0];
                else if(sext_amount_in == 32'h2) begin
                    entries[sext_head] <= in[0];
                    entries[sext_head_plus] <= in[1];
                end
            end
        end
        if(pop)  begin
            tail <= tail_next;
            for(int unsigned i = 0; i < DEPTH; i++) begin
                if(i < sext_tail + sext_amount && i >= sext_tail)
                    out <= entries[i];
            end
        end
        else begin
            out <= 'x;
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

endmodule : ls_queue
