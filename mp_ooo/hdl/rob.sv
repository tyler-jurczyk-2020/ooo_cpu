module rob
import rv32i_types::*;
(
    input reservation_station_t cdb [2],
    input rob_t rob_entry [2]
);


// ROB receives data from CDB and updates commit flag in circular queue
circular_queue #(.QUEUE_TYPE(rob_t)) rob(.*);




endmodule : rob