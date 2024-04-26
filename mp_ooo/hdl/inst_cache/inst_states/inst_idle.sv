module inst_idle
(
    input logic [3:0] wmask,
    input logic rmask,
    input logic [31:0] ufp_addr,
    input logic prefetch_rvalid,
    input logic [31:0] prefetch_raddr,
    output logic [3:0] index,
    
    output logic valid_cpu_rqst
);

assign valid_cpu_rqst = rmask != 1'b0 || wmask != 4'b0;

always_comb begin
    if(prefetch_rvalid)
        index = prefetch_raddr[8:5];
    else
        index = ufp_addr[8:5];
end

endmodule : inst_idle
