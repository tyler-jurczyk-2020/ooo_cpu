module rob();
import rv32i_types::*;

// ROB receives data from CDB and updates commit flag in circular queue
circular_queue #(.QUEUE_TYPE(rob_t)) rob(.*);

endmodule : rob