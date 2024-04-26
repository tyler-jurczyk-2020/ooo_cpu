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
    input logic [31:0] ufp_addr,
    input state_t state,
    input logic ack,
    input logic active_prefetch,
    input logic valid_hit,

    output logic mem_read,
    output logic [CACHE_LINE_SIZE-1:0] set_cache_line,
    output logic set_cache_we,
    output logic allocate_prefetch
);

logic [1:0] ack_reg_counter;
logic valid_hit_reg;

always_ff @(posedge clk) begin
    if(rst) begin
        ack_reg_counter <= 2'b0;
        valid_hit_reg <= 1'b0;
    end
    else begin
        if(active) begin
            if(ack && ack_reg_counter < 2'h2) begin
                valid_hit_reg <= valid_hit;
                ack_reg_counter <= ack_reg_counter + 1'b1;
            end
        end
        else begin
            ack_reg_counter <= 2'h0;
        end
    end
end

always_comb begin
    mem_read = 1'b0;
    if(active && ack && ack_reg_counter == 2'b0)
        mem_read = 1'b1;

    // Send read request
    allocate_prefetch = 1'b0;
    if(active && ack && ack_reg_counter == 2'b1 && active_prefetch && valid_hit_reg) begin
        allocate_prefetch = 1'b1;
    end
    
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
