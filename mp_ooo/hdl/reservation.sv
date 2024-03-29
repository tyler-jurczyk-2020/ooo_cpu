module reservation
import rv32i_types::*;
#(parameter SS = 2)
(
    // reservation station struct 
    input logic clk, rst,
    input reservation_station_t info [SS],
    input logic enable,
    output logic rs_full
);

circular_queue #(.QUEUE_TYPE(reservation_station_t)) issue_q(.clk(clk), .rst(rst), .push(enable), .full(rs_full), .in(info)); 

endmodule : reservation