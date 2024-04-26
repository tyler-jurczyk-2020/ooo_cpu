module writeback 
import cache_types::*;
#(
    parameter               WAYS       = 4,
    parameter               TAG_SIZE   = 24,
    parameter               CACHE_LINE_SIZE = 256
)
(
    input logic clk, rst, active_wb,
    input state_t state,
    input logic [CACHE_LINE_SIZE-1:0] mem_line_to_wb,
    input logic [TAG_SIZE-2:0] tag_to_evict,
    input logic ack,

    output logic [CACHE_LINE_SIZE-1:0] mem_line_wb,
    output logic [TAG_SIZE-2:0] tag_eviction,
    output logic mem_write
);

logic [1:0] ack_reg_counter;

always_ff @(posedge clk) begin
    if(rst) begin
        tag_eviction <= 23'b0;
    end
    else begin
        if(state == compare_tag_s)
            tag_eviction <= tag_to_evict;
    end
end

always_ff @(posedge clk) begin
    if(rst) begin
        ack_reg_counter <= 2'b0;
    end
    else begin
        if(active_wb) begin
            if(ack && ack_reg_counter < 2'h2)
                ack_reg_counter <= ack_reg_counter + 1'b1;
        end
        else begin
            ack_reg_counter <= 2'h0;
        end
    end
end

always_comb begin
    mem_write = 1'b0;
    mem_line_wb = 'x;
    if(active_wb && ack && ack_reg_counter == 2'b0)
        mem_write = 1'b1;
        mem_line_wb = mem_line_to_wb;
    
end

endmodule : writeback
