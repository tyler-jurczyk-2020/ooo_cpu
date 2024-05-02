module pcs_writeback 
import cache_types::*;
#(
    parameter               WAYS       = 4,
    parameter               TAG_SIZE   = 24,
    parameter               CACHE_LINE_SIZE = 256
)
(
    input logic clk, rst, active_wb, mem_resp,
    input state_t state,
    input logic [CACHE_LINE_SIZE-1:0] mem_line_to_wb,
    input logic [TAG_SIZE-2:0] tag_to_evict,

    output logic [CACHE_LINE_SIZE-1:0] mem_line_wb,
    output logic [TAG_SIZE-2:0] tag_eviction,
    output logic mem_write
);

logic mem_resp_reg;
logic pulse_write;

always_ff @(posedge clk) begin
    if(rst) begin
        mem_resp_reg <= 1'b0;
        tag_eviction <= 23'b0;
        pulse_write <= 1'b0;
    end
    else begin
        pulse_write <= active_wb;
        mem_resp_reg <= mem_resp;
        if(state == compare_tag_s)
            tag_eviction <= tag_to_evict;
    end
end

always_comb begin
    if(active_wb && !mem_resp_reg) begin
        mem_line_wb = mem_line_to_wb;
        if(~pulse_write)
            mem_write = 1'b1;
        else
            mem_write = 1'b0;
    end
    else begin
        mem_line_wb = 'x;
        mem_write = 1'b0;
    end
end

endmodule : pcs_writeback
