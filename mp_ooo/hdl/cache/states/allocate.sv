module allocate 
import cache_types::*;
#(
    parameter               WAYS       = 4,
    parameter               TAG_SIZE   = 24,
    parameter               CACHE_LINE_SIZE = 256
)
(
    input logic clk, rst, active, mem_resp, mem_write,
    input logic [CACHE_LINE_SIZE-1:0] mem_line,

    output logic mem_read,
    output logic [CACHE_LINE_SIZE-1:0] set_cache_line,
    output logic set_cache_we
);

logic mem_resp_reg;
logic pulse_read;

always_ff @(posedge clk) begin
    if(rst) begin
        mem_resp_reg <= 1'b0;
        pulse_read <= 1'b0;
    end
    else begin
        pulse_read <= active;
        if(!mem_write)
            mem_resp_reg <= mem_resp;
    end
end

always_comb begin
    // Send read request
    if(active && !mem_resp_reg && ~pulse_read)
        mem_read = 1'b1;
    else
        mem_read = 1'b0;

    // Store request result in cache
    if(mem_resp) begin // AND PLRU is resolved 
        set_cache_we = 1'b0; // Low active
        set_cache_line = mem_line;
    end
    else begin
        set_cache_we = 1'b1; // Low active
        set_cache_line = 'x;
    end
end

endmodule : allocate
