module pcs_idle
(
    input logic [31:0] wmask,
    input logic rmask,
    
    output logic valid_cpu_rqst
);

assign valid_cpu_rqst = rmask != 1'b0 || wmask != 32'b0;

endmodule : pcs_idle
