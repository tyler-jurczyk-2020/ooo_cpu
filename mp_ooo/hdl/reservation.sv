module reservation
import rv32i_types::*;
#(
    parameter SS = 2,
    parameter reservation_table_size = 8,
    parameter ROB_DEPTH = 7 
)
(
    input logic clk, rst,
    // Signals whether instruction is available from rename/dispatch
    input logic avail_inst,
    // reservation station struct     
    input dispatch_reservation_t reservation_entry [SS],

    input logic write_from_fu [SS],
    input fu_output_t cdb [SS], 
    input logic alu_status [SS], mult_status [SS],

    // Input from Physical Register File
    input logic [7:0] reservation_rob_id [SS],

    output fu_input_t inst_for_fu [SS], 
    // inform instruction queue to pause if our reservation table is full. 
    output logic table_full,
    // Send out requests for fu inputs
    output physical_reg_request_t fu_request [SS]
);

// *could possibly combine reg files. 

// register source # that the reserevation station entries utilize
// Valid bit to see whether that the entry is empty or not 
// Busy bit to see whether that the reservation station can send another value or not
// What phys source registers does instructon utilize
// Which functional unit does the instruction need? 
// We can assume that due to register renaming, that if a younger instruction makes it
// through the functional unit first, then it won't be updating the same source register
// that an older entry is depending on 

reservation_entry_t reservation_table[SS][reservation_table_size]; 
//update size based on reservation table size
logic [2:0] counter; 

fu_input_t local_inst_fu [SS]; 

always_ff @ (posedge clk) begin
    if(rst) begin
        for(int i = 0; i < SS; i++) begin
            for(int j = 0; j < reservation_table_size; j++) begin
                reservation_table[i][j].valid <= '0; 
            end
        end
        // local_inst_fu <= '0; // Also wrong type
    end
    // Enter to table
    else if(~table_full) begin
        // insert new entry if there's an available one. Maintain counter for space
        // Additional for loop because we will have N-entries at once based on N-way superscalar
        for(int i = 0; i < SS; i++) begin 
            for(int j = 0; j < reservation_table_size; j++) begin
                if(avail_inst && ~reservation_table[i][j].valid) begin
                    reservation_table[i][j].reservation_entry <= reservation_entry[i]; 
                    reservation_table[i][j].valid <= '1; 
                    // MUST break because otherwise the entry will be put in to every available spot in the table
                    break; 
                end
            end
        end
    end
    // Check all table entries to see whether we need to update them
    for(int i = 0; i < SS; i++) begin 
        local_inst_fu[i].start_calculate <= '0; 
        for(int j = 0; j < reservation_table_size; j++) begin
            if(reservation_table[i][j].reservation_entry.rob.rs1_source == reservation_rob_id[i] && write_from_fu[i]) begin
                reservation_table[i][j].reservation_entry.rob.input1_met <= '1;  
            end
            if(reservation_table[i][j].reservation_entry.rob.rs2_source == reservation_rob_id[i] && write_from_fu[i]) begin
                reservation_table[i][j].reservation_entry.rob.input2_met <= '1; 
            end
            // See whether to issue any entry
            if((reservation_table[i][j].reservation_entry.inst.alu_en || reservation_table[i][j].reservation_entry.inst.cmp_en ||
              (reservation_table[i][j].reservation_entry.inst.is_mul && mult_status[i])) 
              && reservation_table[i][j].valid) begin
                if(reservation_table[i][j].reservation_entry.rob.input1_met && reservation_table[i][j].reservation_entry.rob.input2_met) begin
                    local_inst_fu[i].inst_info <= reservation_table[i][j];
                    local_inst_fu[i].start_calculate <= '1; 
                    reservation_table[i][j].valid <= '0; 
                    // Issue request to register file rs_entries[i].rvfi.valid = instruction[i].valid;
                    if(reservation_table[i][j].reservation_entry.inst.rs1_s != 5'b0) begin
                        fu_request[i].rs1_en <= 1'b1;
                        fu_request[i].rs1_s <= reservation_table[i][j].reservation_entry.rat.rs1;
                    end
                    else begin
                        fu_request[i].rs1_en <= 1'b0;
                        fu_request[i].rs1_s <= 'x;
                    end
                    if(reservation_table[i][j].reservation_entry.inst.rs2_s != 5'b0) begin
                        fu_request[i].rs2_en <= 1'b1;
                        fu_request[i].rs2_s <= reservation_table[i][j].reservation_entry.rat.rs2;
                    end
                    else begin
                        fu_request[i].rs2_en <= 1'b0;
                        fu_request[i].rs2_s <= 'x;
                    end
                    break; 
                end
            end
        end
    end
end

assign inst_for_fu = local_inst_fu;

always_comb begin
    // Number of occupied entries in the table
    counter = '0;
    for(int i = 0; i < SS; i++) begin
        for(int j = 0; j < reservation_table_size; j++) begin
            if(reservation_table[i][j].valid) begin
                counter = counter + 1'b1;
            end
        end
    end

    // Table full
    table_full = '0; 
    if({{29{1'b0}},counter} >= ROB_DEPTH-SS) begin // Probably need to fix width
        table_full = '1; 
    end
end

endmodule : reservation
