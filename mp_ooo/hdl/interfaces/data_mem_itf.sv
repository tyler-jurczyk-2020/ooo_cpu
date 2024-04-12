interface data_mem_itf(
    input  logic    clk,
    input  logic    rst,
    input  logic    [31:0]    addr,
    input  logic             rmask,
    input  logic    [3:0]    wmask,
    output logic    [31:0]   rdata,
    input  logic    [31:0]   wdata,
    output logic    resp
);

endinterface
