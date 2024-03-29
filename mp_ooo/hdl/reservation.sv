module reservation
import rv32i_types::*;
(
    // reservation station struct 
    input reservation_station_t info [2],
    input logic enable,
    output logic rs_full
);

circular_queue #(.QUEUE_TYPE(reservation_station_t)) issue_q(.push(enable), .full(rs_full), .in(info));

endmodule : reservation