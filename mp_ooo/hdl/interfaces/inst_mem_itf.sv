interface inst_mem_itf(
    input  logic    clk,
    input  logic    rst,
    input  logic    [31:0]     addr,
    input  logic               rmask,
    output logic    [255:0]    rdata,
    output logic    resp
);

endinterface
