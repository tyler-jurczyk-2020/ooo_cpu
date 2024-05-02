module freelist
    import rv32i_types::*;
    #(
        type QUEUE_TYPE = logic[5:0],
        parameter SS = 2,
        parameter IN_WIDTH = SS, 
        parameter SEL_IN = 2,
        parameter SEL_OUT = 2,
        parameter DEPTH = 32
    )(
        input logic clk, rst,
        input logic push, push2, pop, pop2,
        input QUEUE_TYPE in [IN_WIDTH], // Values pushed in
        input QUEUE_TYPE reg_in [SEL_IN], // Values used to modify entries
        
        input logic [$clog2(DEPTH)-1:0] reg_select_in [SEL_IN], reg_select_out [SEL_OUT],
        input logic [SEL_IN-1:0] in_bitmask,
        input logic [SEL_OUT-1:0] out_bitmask,
     
        input logic flush,
    
        // Need to consider potentially how partial pushes/pops may work in superscalar context
        output logic empty,
        output logic full,
        output logic [$clog2(DEPTH)-1:0] head_out, tail_out,
        output QUEUE_TYPE out [SS], // Values pushed out
        output QUEUE_TYPE reg_out [SEL_OUT] // Values selected to be observed
        );
    
    QUEUE_TYPE entries [DEPTH];
    logic [$clog2(DEPTH):0] head, tail, head_next, tail_next, head_spec; // One bit to differentiate between full/empty
    logic [31:0] sext_head, sext_tail, sext_head_plus, sext_tail_plus, sext_amount, sext_amount_in, sext_amount_out;
    logic [$clog2(DEPTH):0] head_backup, tail_backup;
    logic [$clog2(DEPTH):0] adjust_amt_push, adjust_amt_pop;

    assign adjust_amt_push = {sext_amount_in[$clog2(DEPTH):0]};
    assign adjust_amt_pop = {sext_amount[$clog2(DEPTH):0]};
    
    assign head_out = head[$clog2(DEPTH)-1:0];
    assign tail_out = tail[$clog2(DEPTH)-1:0];
    
    assign head_spec = head + SS[$clog2(DEPTH):0]; // Need to make superscalar
    
    assign empty = (head == tail);
    
    assign sext_head = {{(32-$clog2(DEPTH)-1){1'b0}}, head[$clog2(DEPTH)-1:0]}; // Excludes top bit so queue is indexed properly
    assign sext_tail = {{(32-$clog2(DEPTH)-1){1'b0}}, tail[$clog2(DEPTH)-1:0]};
    assign sext_head_plus = {{(32-$clog2(DEPTH)-1){1'b0}}, head[$clog2(DEPTH)-1:0] + 1'b1};
    assign sext_tail_plus = {{(32-$clog2(DEPTH)-1){1'b0}}, tail[$clog2(DEPTH)-1:0] + 1'b1};
    
    assign head_next = head + adjust_amt_push;
    assign tail_next = tail + adjust_amt_pop;
     
    // Determine how many to pop and push
    always_comb begin
        sext_amount = '0; // pop_out amount
        sext_amount_in = '0; // push amount
        if(pop)
            sext_amount = sext_amount + 1'b1;
        if(pop2)
            sext_amount = sext_amount + 1'b1;
        if(push)
            sext_amount_in = sext_amount_in + 1'b1;
        if(push2)
            sext_amount_in = sext_amount_in + 1'b1;
    end
    
    always_comb begin
        // if(~push)
        //    full = (head[$clog2(DEPTH)-1:0] == tail[$clog2(DEPTH)-1:0]) && (head[$clog2(DEPTH)] != tail[$clog2(DEPTH)]);
        // else
        // Always use speculative full?
            full = (head_spec[$clog2(DEPTH)-1:0] == tail[$clog2(DEPTH)-1:0]) && (head_spec[$clog2(DEPTH)] != tail[$clog2(DEPTH)]);
    end
    
    always_ff @(posedge clk) begin
        if(rst) begin
            head <= 6'b100000;
            head_backup <= 6'b100000;
            tail <= '0;
            tail_backup <= '0;
            for(int unsigned i = 32; i < 32 + unsigned'(DEPTH); i++) begin
                entries[i-32] <= ($bits(QUEUE_TYPE))'(i);
            end
        end
        else begin
            if(flush) begin
                if(push || push2) begin
                    head <= head_backup + adjust_amt_push;
                    tail <= tail_backup + adjust_amt_push;
                end
                else begin
                    head <= head_backup;
                    tail <= tail_backup;
                end
            end
            else begin
                if(push || push2)
                    head <= head_next;
                if(pop || pop2)
                    tail <= tail_next;
            end
    
            if(push || push2) begin           
                head_backup <= head_backup + adjust_amt_push;
                tail_backup <= tail_backup + adjust_amt_push;

                if(push)
                    entries[sext_head] <= in[0];

                if(push2 && sext_amount_in == 32'h1)
                    entries[sext_head] <= in[1];
                else if(push2 && sext_amount_in == 32'h2)
                    entries[sext_head_plus] <= in[1];
            end
            
            if(pop || pop2) begin
                if(pop)
                    out[0] <= entries[sext_tail];

                if(pop2 && sext_amount == 32'h1)
                    out[1] <= entries[sext_tail];
                if(pop2 && sext_amount == 32'h2)
                    out[1] <= entries[sext_tail_plus];
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
    
    endmodule : freelist