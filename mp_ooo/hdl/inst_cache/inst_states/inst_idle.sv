module inst_idle
(
    input logic [3:0] wmask,
    input logic rmask,
    
    output logic valid_cpu_rqst
);

assign valid_cpu_rqst = rmask != 1'b0 || wmask != 4'b0;

endmodule : inst_idle
