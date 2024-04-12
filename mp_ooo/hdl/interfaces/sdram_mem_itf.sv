interface sdram_mem_itf(
        input  logic            clk,
        input  logic            rst,

        output  logic   [31:0]  addr,
        output  logic           read,
        output  logic           write,
        output  logic   [63:0]  wdata,
        input   logic           ready,

        input   logic   [63:0]  rdata,
        input   logic   [31:0]  raddr,
        input   logic           rvalid
);

endinterface
