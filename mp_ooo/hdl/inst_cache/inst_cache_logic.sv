module inst_cache_logic
import cache_types::*;
#(
    parameter               WAYS       = 4,
    parameter               TAG_SIZE   = 24,
    parameter               CACHE_LINE_SIZE = 256,
    parameter               READ_SIZE = 32
)
(
    input logic clk, rst, mem_resp,
    input logic [31:0] cpu_wdata,
    input logic [TAG_SIZE-2:0] target_tag,
    input logic [CACHE_LINE_SIZE-1:0] mem_line,
    input logic ways_valid [WAYS],
    input logic [TAG_SIZE-1:0] ways_tags [WAYS],
    input logic [CACHE_LINE_SIZE-1:0] ways_lines [WAYS],
    input state_t state,
    input logic rmask,
    input logic [3:0] wmask,
    input logic [2:0] plru_bits,
    input logic [4:0] offset,
    input logic [31:0] ufp_addr,
    // Indicates the current cache is being serviced
    input logic ack,
    input logic [255:0] prefetch_rdata,
    input logic prefetch_rvalid,
    input logic [31:0] prefetch_raddr,

    // PLRU drivers
    output logic [2:0] set_plru_bits,
    output logic plru_we,
    // Control unit
    output logic valid_hit, valid_cpu_rqst, dirty,
    //Memory signals
    output logic mem_read, mem_write,
    output logic [CACHE_LINE_SIZE-1:0] mem_line_wb,
    output logic [31:0] prefetch_addr,
    output logic prefetch,

    //Cache signals
    output logic set_ways_valid [WAYS], set_ways_valid_we [WAYS], set_ways_data_we [WAYS], set_ways_tags_we [WAYS],
    output logic [CACHE_LINE_SIZE-1:0] set_ways_lines [WAYS],
    output logic [TAG_SIZE-1:0] set_ways_tags [WAYS],
    output logic [31:0] wb_mask,
    // Cpu driving signals
    output logic [READ_SIZE-1:0] cpu_data,
    output logic cpu_resp,
    // Drive address computation
    output logic [31:0] set_way,
    output logic [TAG_SIZE-2:0] tag_eviction,
    // Prefetch
    input logic active_prefetch,
    output logic [3:0] index,
    output logic flush_prefetch
);

logic set_cache_we, active, active_wb, update_plru;
logic [TAG_SIZE-2:0] set_tag, tag_to_evict;
way_t set_way_enum;
logic [31:0] way_hit;
logic [CACHE_LINE_SIZE-1:0] set_cache_line, mem_line_to_wb, aligned_wdata;

// Prefetch signals
logic allocate_prefetch;

inst_plru plru(.*);
inst_idle idle(.*);
inst_compare_tag compare_tag(.*);
inst_allocate allocate(.*);
inst_writeback writeback(.*);

assign set_way = (set_way_enum == F) ? 'x : set_way_enum; // F denotes don't care
assign aligned_wdata = cpu_wdata << 8*offset;
assign tag_to_evict = ways_tags[set_way][TAG_SIZE-2:0];

// Cpu drivers
always_comb begin
    if(state == compare_tag_s && valid_hit) begin
        if(wmask != 4'b0)
            cpu_data = 'x;
        else
            cpu_data = ways_lines[way_hit][(8*{offset[4:2],2'b0})+:READ_SIZE];
        cpu_resp = 1'b1;
        update_plru = 1'b1;
    end
    else begin
        cpu_data = 'x; 
        cpu_resp = 1'b0;
        if(state == idle_s && prefetch_rvalid)
            update_plru = 1'b1;
        else
            update_plru = 1'b0;
    end
end

// Cache memory drivers
always_comb begin
    // Defaults
    flush_prefetch = 1'b0;
    for(int i = 0; i < WAYS; i++) begin
        set_ways_lines[i] = 'x;
        set_ways_data_we[i] = 1'b1;
        set_ways_tags[i] = 'x;
        set_ways_tags_we[i] = 1'b1;
        set_ways_valid[i] = 'x;
        set_ways_valid_we[i] = 1'b1;
    end
    // Compare tag signals
    if(state == idle_s && prefetch_rvalid) begin
        flush_prefetch = 1'b1;
        for(int i = 0; i < WAYS; i++) begin
            if(i == signed'(set_way)) begin
                set_ways_tags[i] = {1'b0, prefetch_raddr[31:9]};
                set_ways_tags_we[i] = 1'b0; // Low Active
                // Update to valid so when we get back to this state we get
                // cache hit
                set_ways_valid[i] = 1'b1;
                set_ways_valid_we[i] = 1'b0;
                set_ways_lines[i] = prefetch_rdata;
                set_ways_data_we[i] = 1'b0;
            end
        end
    end

    if(state == compare_tag_s) begin
        for(int i = 0; i < WAYS; i++) begin
            if(i == signed'(set_way) && !valid_hit && ~active_prefetch) begin
                if(wmask != 4'b0)
                    set_ways_tags[i] = {1'b1, set_tag};
                else
                    set_ways_tags[i] = {1'b0, set_tag};
                set_ways_tags_we[i] = 1'b0; // Low Active
                // Update to valid so when we get back to this state we get
                // cache hit
                set_ways_valid[i] = 1'b1;
                set_ways_valid_we[i] = 1'b0;
            end
            else begin
                if(i == signed'(way_hit) && valid_hit && wmask != 4'b0) begin
                    set_ways_tags[i] = {1'b1, ways_tags[i][TAG_SIZE-2:0]};
                    set_ways_tags_we[i] = 1'b0;
                end
            end
        end
    end
    
    // Cacheline signals
    if(state == allocate_s || state == compare_tag_s) begin
        for(int i = 0; i < WAYS; i++) begin
            if(i == signed'(set_way) && state == allocate_s) begin
                set_ways_lines[i] = set_cache_line;
                set_ways_data_we[i] = set_cache_we;
            end
            else if(i == signed'(way_hit) && valid_hit && wmask != 4'b0 && state == compare_tag_s) begin
                set_ways_lines[i] = aligned_wdata;
                set_ways_data_we[i] = 1'b0;
            end
        end
    end

    // Allocate specific signals
    if(state == allocate_s)
        active = 1'b1;
    else
        active = 1'b0;

    // Writeback signals
    if(state == writeback_s) begin
        active_wb = 1'b1;
        mem_line_to_wb = ways_lines[set_way];
    end
    else begin
        active_wb = 1'b0;
        mem_line_to_wb = 'x;
    end

    // Prefetch signals
    if((state == post_prefetch_s && ~valid_hit || (state == allocate_s && allocate_prefetch))) begin
        prefetch_addr = {ufp_addr[31:5], 5'b0} + 6'h20; 
        prefetch = 1'b1;
    end
    else begin
        prefetch_addr = 'x;
        prefetch = 1'b0;
    end
end

endmodule : inst_cache_logic
