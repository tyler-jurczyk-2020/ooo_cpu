module idle
(
    input logic [3:0] rmask, wmask,
    
    output logic valid_cpu_rqst
);

assign valid_cpu_rqst = rmask != 4'b0 || wmask != 4'b0;

endmodule : idle
