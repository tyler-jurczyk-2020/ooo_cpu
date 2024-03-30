module reservation
import rv32i_types::*;
#(
    parameter SS = 2,
    parameter reservation_table_size = 8,
    parameter ROB_DEPTH = 8 
)
(
    input logic clk, rst,
    // reservation station struct     
    input dispatch_reservation_t reservation_entry [SS],

    input [ROB_DEPTH-1:0] updated_rob, 
    input logic fu_enable, 

    output dispatch_reservation_t inst_for_fu [SS], 
    // inform instruction queue to pause if our reservation table is full. 
    output logic station_full
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

reserevation_entry_t reservation_table[SS][reservation_table_size]; 
//update size based on reservation table size
logic [2:0] counter; 
logic table_full;

assign table_full = 1'b0;

always_ff @ (posedge clk) begin
    if(rst) begin
        for(int i = 0; i < SS; i++) begin 
            for(int j = 0; j < reservation_table_size; j++) begin
                reservation_table[i][j].valid <= '0; 
            end
        end
    end
    // Enter to table
    else if(~table_full) begin
        // insert new entry if there's an available one. Maintain counter for space
        for(int i = 0; i < SS; i++) begin 
            for(int j = 0; j < reservation_table_size; j++) begin
                if(~reservation_table[i][j].valid) begin
                    reservation_table[i][j].reservation_entry <= reservation_entry; 
                    reservation_table[i][j].valid <= '1; 
                    counter <= counter + 3'd1; 
                    break; 
                end
            end
        end
    end
end

// Check all table entries to see whether we need to update them
always_ff @ (posedge clk) begin
    for(int i = 0; i < SS; i++) begin 
        for(int j = 0; j < reservation_table_size; j++) begin
            if(reservation_table[i][j].reservation_entry.rs1_source == updated_rob) begin
                reservation_table[i][j].reservation_entry.rs1_met <= '1; 
            end
            if(reservation_table[i][j].reservation_entry.rs2_source == updated_rob) begin
                reservation_table[i][j].reservation_entry.rs2_met <= '1; 
            end
        end
    end
end

// Check all table entries to see if we can release them 
always_ff @ (posedge clk) begin
    for(int i = 0; i < SS; i++) begin 
        for(int j = 0; j < reservation_table_size; j++) begin
            if(fu_enable) begin
                if(reservation_table[i][j].reservation_entry.rs1_met && reservation_table[i][j].reservation_entry.rs2_met) begin
                    inst_for_fu <= reservation_entry; 
                    reservation_table[i][j].valid <= '0; 
                    counter <= counter - 3'd1; 
                    break; 
                end
            end
        end
    end
end


always_comb begin
    station_full = '0; 
    if(counter == 3'd7) begin
        station_full = '1; 
    end
end

endmodule : reservation
