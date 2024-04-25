module inst_allocate 
import cache_types::*;
#(
    parameter               WAYS       = 4,
    parameter               TAG_SIZE   = 24,
    parameter               CACHE_LINE_SIZE = 256
)
(
    input logic clk, rst, active, mem_resp, mem_write,
    input logic [CACHE_LINE_SIZE-1:0] mem_line,
    input state_t state,

    output logic mem_read,
    output logic [CACHE_LINE_SIZE-1:0] set_cache_line,
    output logic set_cache_we
);

logic mem_resp_reg;
logic pulse_read;
logic pulse_read_to_check;
logic write_reg;

always_ff @(posedge clk) begin
    if(rst) begin
        mem_resp_reg <= 1'b0;
        pulse_read <= 1'b0;
    end
    else begin
        pulse_read <= active;
        if(state == allocate_s && ~pulse_read)
            pulse_read_to_check <= 1'b1;
        else
            pulse_read_to_check <= 1'b0;

        if(!mem_write)
            mem_resp_reg <= mem_resp;
    end
end

always_comb begin
    // Send read request
    if(active && pulse_read_to_check)
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

endmodule : inst_allocate
