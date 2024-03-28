module reservation
import rv32i_types::*;
#(
    parameter WIDTH = 32
)
(
    // reservation station struct 
    input reservation_station_t info [2],
    input logic enable,

    output logic rs_full,
    output reservation_station_t updated_info
);

reservation_station_t internal_table [WIDTH];


endmodule : reservation