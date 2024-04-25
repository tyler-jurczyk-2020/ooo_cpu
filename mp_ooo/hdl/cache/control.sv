module control
import cache_types::*;
(
    input logic clk, rst, valid_cpu_rqst, valid_hit, dirty, mem_resp, write,
    input [4:0] offset,
    
    output state_t state
);

state_t next_state;
logic mem_resp_reg;
logic write_reg;

always_ff @(posedge clk) begin
    if(rst) begin
       state <= idle_s; 
       mem_resp_reg <= 1'b0;
       write_reg <= 1'b0;
    end
    else begin
        state <= next_state;
        if(!write && !write_reg)
            mem_resp_reg <= mem_resp;

        if(write)
            write_reg <= 1'b1;
        else if(state != writeback_s)        
            write_reg <= 1'b0;
    end
end

always_comb begin
    if(state == idle_s && valid_cpu_rqst) begin
       next_state = compare_tag_s; 
    end
    else if(state == compare_tag_s) begin
        unique case(valid_hit)
            1'b1: begin
                if(offset == 5'b0)
                    next_state = prefetch_s;
                else
                    next_state = idle_s;
            end
            1'b0: begin 
                if(dirty)
                    next_state = writeback_s;
                else
                    next_state = allocate_s;
            end
        endcase
    end
    else if(state == allocate_s) begin
        if(!mem_resp_reg) 
            next_state = allocate_s;
        else
            next_state = compare_tag_s;
    end
    else if(state == writeback_s)begin
        if(!mem_resp)
            next_state = writeback_s;
        else
            next_state = allocate_s;
    end
    else
        next_state = state;
end

endmodule : control
