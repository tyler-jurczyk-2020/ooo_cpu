module rob
import rv32i_types::*;
#(
    parameter SS = 2
)(
    input dispatch_reservation_t cdb [SS],
    input rob_t rob_entry 
);


// ROB receives data from CDB and updates commit flag in circular queue
circular_queue #(.QUEUE_TYPE(rob_t)) rob_dut();




endmodule : rob
