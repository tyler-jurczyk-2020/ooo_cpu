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
    input state_t state,
    input logic [31:0] ufp_addr,
    // Cache Arbiter Signals
    input logic in_service,

    output logic mem_read,
    output logic [CACHE_LINE_SIZE-1:0] set_cache_line,
    output logic set_cache_we,
    output logic [31:0] allocate_addr,
    output logic prefetch
);

logic [1:0] service_counter;
logic mem_resp_reg;
logic pulse_read;
logic pulse_read_to_check;
logic write_reg;
logic [31:0] ufp_cacheline_addr;

assign ufp_cacheline_addr = {ufp_addr[31:5], 5'b0};

always_ff @(posedge clk) begin
    if(rst) begin
        mem_resp_reg <= 1'b0;
        pulse_read <= 1'b0;
        service_counter <= 2'b0;
    end
    else begin
        pulse_read <= active;
        if(state == allocate_s && ~pulse_read)
            pulse_read_to_check <= 1'b1;
        else
            pulse_read_to_check <= 1'b0;

        if(!mem_write)
            mem_resp_reg <= mem_resp;


        if(active && in_service && service_counter < 2'h2)
            service_counter <= service_counter + 1'b1;
        else if(~active)
            service_counter <= 2'b0;
    end
end

always_comb begin
    // Send read request
    if(active && in_service && service_counter == 2'b00) begin
        mem_read = 1'b1;
        allocate_addr = ufp_cacheline_addr;
        prefetch = 1'b0;
    end
    else if(active && service_counter == 2'b01) begin
        mem_read = 1'b1;
        allocate_addr = ufp_cacheline_addr + 6'h20;
        prefetch = 1'b1;
    end
    else begin
        mem_read = 1'b0;
        allocate_addr = 'x;
        prefetch = 1'b0;
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

endmodule : allocate
