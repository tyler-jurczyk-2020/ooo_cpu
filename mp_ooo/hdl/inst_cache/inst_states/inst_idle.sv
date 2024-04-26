module inst_idle
import cache_types::*;
(
    input logic [3:0] wmask,
    input logic rmask,
    input logic [31:0] ufp_addr,
    input logic prefetch_rvalid,
    input logic [31:0] prefetch_raddr,
    output logic [3:0] index,
    input state_t state,
    
    output logic valid_cpu_rqst
);

logic [31:0] prefetch_addr;

assign prefetch_addr = { ufp_addr[31:5], 5'b0 };
assign valid_cpu_rqst = rmask != 1'b0 || wmask != 4'b0;

always_comb begin
    if(prefetch_rvalid && state == idle_s)
        index = prefetch_raddr[8:5];
    else if(state == compare_tag_s)
        index = prefetch_addr[8:5];
    else
        index = ufp_addr[8:5];
end

endmodule : inst_idle
