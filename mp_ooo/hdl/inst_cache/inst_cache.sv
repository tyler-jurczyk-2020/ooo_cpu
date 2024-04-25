module inst_cache 
import cache_types::*;
#(
    parameter               WAYS       = 4,
    parameter               TAG_SIZE   = 24,
    parameter               CACHE_LINE_SIZE = 256,
    parameter               READ_SIZE = 32,
    parameter               OFFSET = 3
)(
    input   logic           clk,
    input   logic           rst,

    // cpu side signals, ufp -> upward facing port
    input   logic   [31:0]  ufp_addr,
    input   logic   ufp_rmask,
    input   logic   [3:0]   ufp_wmask,
    output  logic   [READ_SIZE-1:0]  ufp_rdata,
    input   logic   [31:0]  ufp_wdata,
    output  logic           ufp_resp,

    // memory side signals, dfp -> downward facing port
    output  logic   [31:0]  dfp_addr,
    output  logic           dfp_read,
    output  logic           dfp_write,
    input   logic   [255:0] dfp_rdata,
    output  logic   [255:0] dfp_wdata,
    input   logic           dfp_resp,
    input logic ack,
    input logic [255:0] prefetch_rdata,
    input logic prefetch_rvalid,
    output logic prefetch
);

    // 3-bit PLRU per set
    logic [2:0] plru_bits;
    logic [2:0] set_plru_bits;
    logic plru_we;
    logic [4:0] offset;
    // Control unit inputs
    logic dirty, valid_hit, valid_cpu_rqst;
    // Control unit outputs
    state_t state;
    // Ways inputs to cache_logic
    logic ways_valid [WAYS];
    logic [TAG_SIZE-1:0] ways_tags [WAYS];
    logic [CACHE_LINE_SIZE-1:0] ways_lines [WAYS];
    // Drive ways from cache_logic
    logic set_ways_valid [WAYS], set_ways_valid_we [WAYS], set_ways_data_we [WAYS], set_ways_tags_we [WAYS];
    logic [TAG_SIZE-1:0] set_ways_tags [WAYS];
    logic [CACHE_LINE_SIZE-1:0] set_ways_lines [WAYS];
    // Memory signals
    logic mem_resp;
    logic [31:0] prefetch_addr;
    // Aliases
    logic [3:0] index;
    logic [TAG_SIZE-2:0] target_tag;
    logic [31:0] data_mask, wb_mask, set_way;
    logic [TAG_SIZE-2:0] tag_eviction;

    assign index = ufp_addr[8:5];
    assign target_tag = ufp_addr[31:9];
    assign offset = ufp_addr[4:0];

    // Address/mask computations
    always_comb begin
        if(state == compare_tag_s)
            data_mask = wb_mask;
        else if(state == allocate_s)
            data_mask = 32'hffffffff;
        else
            data_mask = 'x;

        if(state == allocate_s)
            dfp_addr = { ufp_addr[31:5], 5'b0};
        else if(state == writeback_s)
            dfp_addr = { tag_eviction, index, 5'b0 };
        else
            dfp_addr = 'x;
    end

    inst_control control_unit(.*, .mem_resp(dfp_resp), .write(dfp_write));
    inst_cache_logic #(.READ_SIZE(READ_SIZE)) cache_logic(.*, .wmask(ufp_wmask), .rmask(ufp_rmask), .mem_read(dfp_read), .mem_write(dfp_write),
                .mem_line(dfp_rdata), .mem_line_wb(dfp_wdata), .mem_resp(dfp_resp), .cpu_data(ufp_rdata), .cpu_wdata(ufp_wdata), .cpu_resp(ufp_resp), .offset(ufp_addr[4:0]));

    inst_ff_array #(.WIDTH(3)) plru_array(
        .clk0       (clk),
        .rst0       (rst),
        .csb0       (1'b0),
        .web0       (plru_we),
        .addr0      (index),
        .din0       (set_plru_bits),
        .dout0      (plru_bits)
    );

    generate for (genvar i = 0; i < 4; i++) begin : arrays
        mp_cache_data_array data_array (
            .clk0       (clk),
            .csb0       (1'b0),
            .web0       (set_ways_data_we[i]),
            .wmask0     (data_mask),
            .addr0      (index),
            .din0       (set_ways_lines[i]),
            .dout0      (ways_lines[i])
        );
        mp_cache_tag_array tag_array (
            .clk0       (clk),
            .csb0       (1'b0),
            .web0       (set_ways_tags_we[i]),
            .addr0      (index),
            .din0       (set_ways_tags[i]),
            .dout0      (ways_tags[i])
        );
        inst_ff_array #(.WIDTH(1)) valid_array (
            .clk0       (clk),
            .rst0       (rst),
            .csb0       (1'b0),
            .web0       (set_ways_valid_we[i]),
            .addr0      (index),
            .din0       (set_ways_valid[i]),
            .dout0      (ways_valid[i])
        );
    end endgenerate

endmodule
