module reservation_table
    import rv32i_types::*;
    #(
        parameter SS = 2,
        parameter reservation_table_size = 8,
        parameter ROB_DEPTH = 7,
        parameter reservation_table_type_t TABLE_TYPE = ALU_T,
        parameter REQUEST = 2
    )
    (
        input clk, rst,

        /////////////// WRITING TO TABLE ///////////////
        // get entry from the dispatcher 
        input super_dispatch_t dispatched [SS], 

        // indicates whether dispatched signal is new signal
        input logic avail_inst, 

        /////////////// ISSUING FROM TABLE ///////////////
        output fu_input_t inst_for_fu [REQUEST], // *parameterize!

        /////////////// RETRIEVING UPDATED DEPENDECY FROM FU (CDB) ///////////////
        input cdb_t cdb_rob_ids, 

        /////////////// REQUESTING REGISTER VALUE FROM PHYS. REG. FILE ///////////////
        output physical_reg_request_t fu_request [REQUEST],

        /////////////// FU FULL - DON'T ISSUE ///////////////
        input logic FU_Ready [REQUEST], 
        
        /////////////// STALL DISPATCHING ///////////////
        output logic table_full

    );

    fu_input_t inst_for_fu0 [REQUEST]; // *parameterize!
    physical_reg_request_t fu_request0 [REQUEST];
    logic internal_full;


    // have some sort of reg_value and reg_value_next
    // always_comb updates reg_value_next to some value
    // always_ff updates reg_value to reg_value_next


    // table. Packed array
    super_dispatch_t reservation_table [reservation_table_size]; 

    // Determine for determing whether table is full or not 
    logic [$clog2(reservation_table_size):0] counter; 

    
    // Write to the table 
    always_ff @(posedge clk) begin
        if(rst) begin
            for(int j = 0; j < reservation_table_size; j++) begin
                reservation_table[j].rs_entry.full <= '0; 
            end
            // for(int i = 0; i < REQUEST; i++) begin
            //     inst_for_fu0[i] <= '0;
            //     fu_request0[i] <= '0; 
            // end            
        end
        // Write new entry
        else begin
            if(avail_inst && ~internal_full) begin
                for(int i = 0; i < SS; i++) begin
                    for(int j = 0; j < reservation_table_size; j++) begin
                        // Need to check to make sure we dont put any loads and stores in the table
                        if(~reservation_table[j].rs_entry.full && (dispatched[i].inst.is_mul == TABLE_TYPE)
                           && dispatched[i].inst.rmask == 4'b0 && dispatched[i].inst.wmask == 4'b0) begin
                            reservation_table[j] <= dispatched[i]; 
                            reservation_table[j].rs_entry.full <= '1; 
                            // MUST break because otherwise the entry will be put in to every available spot in the table
                            // Go next dispatched instruction
                            break;
                        end
                    end
                end
            end
            // For a given CDB, Check whether we need to update any of the Entries
            for(int i = 0; i < CDB; i++) begin
                for(int j = 0; j < reservation_table_size; j++) begin
                    if(reservation_table[j].rs_entry.full && cdb_rob_ids[i].ready_for_writeback && reservation_table[j].rs_entry.rs1_source == cdb_rob_ids[i].inst_info.rob.rob_id) begin
                        reservation_table[j].rs_entry.input1_met <= '1; 
                    end

                    if(reservation_table[j].rs_entry.full && cdb_rob_ids[i].ready_for_writeback && reservation_table[j].rs_entry.rs2_source == cdb_rob_ids[i].inst_info.rob.rob_id) begin
                        reservation_table[j].rs_entry.input2_met <= '1; 
                    end
                end
            end

            for(int i = 0; i < REQUEST; i++) begin
                for(int j = 0; j < reservation_table_size; j++) begin
                    if(reservation_table[j].rs_entry.full && reservation_table[j].rs_entry.input1_met && reservation_table[j].rs_entry.input2_met) begin
                        if(FU_Ready[i]) begin
                            reservation_table[j].rs_entry.full <= '0;
                            // inst_for_fu0[i].inst_info <= reservation_table[j]; 
                            // inst_for_fu0[i].start_calculate <= '1; 
                            // fu_request0[i].rs1_s <= reservation_table[j].rat.rs1;
                            // fu_request0[i].rs2_s <= reservation_table[j].rat.rs2;
                            // inst_for_fu0[i].inst_info.rob.commit <= '1; 
                            break;
                        end
                    end
                    // else begin
                    //     inst_for_fu0[i].start_calculate <= '0; 
                    // end
                end
            end
        end
    end

    always_comb begin
        for(int i = 0; i < REQUEST; i++) begin
            inst_for_fu0[i] = '0; 
            fu_request0[i] = '0; 
        end
        for(int i = 0; i < REQUEST; i++) begin
            for(int j = 0; j < reservation_table_size; j++) begin
                if(reservation_table[j].rs_entry.full && reservation_table[j].rs_entry.input1_met && reservation_table[j].rs_entry.input2_met) begin
                    if(FU_Ready[i]) begin
                        // reservation_table[j].rs_entry.full <= '0;
                        inst_for_fu0[i].inst_info = reservation_table[j]; 
                        inst_for_fu0[i].start_calculate = '1; 
                        fu_request0[i].rs1_s = reservation_table[j].rat.rs1;
                        fu_request0[i].rs2_s = reservation_table[j].rat.rs2;
                        inst_for_fu0[i].inst_info.rob.commit = '1; 
                        break;
                    end
                end
                else begin
                    inst_for_fu0[i].start_calculate = '0; 
                end
            end
        end
    end


    always_ff @ (posedge clk) begin
        if(rst) begin
            for(int i = 0; i < REQUEST; i++) begin
                inst_for_fu[i] <= '0; 
                fu_request[i] <= '0; 
            end
        end
        else begin
            inst_for_fu <= inst_for_fu0; 
            fu_request <= fu_request0; 
        end
    end


always_comb begin
    // Number of occupied entries in the table
    counter = '0;
    for(int i = 0; i < SS; i++) begin
        for(int j = 0; j < reservation_table_size; j++) begin
            if(reservation_table[j].rs_entry.full) begin
                counter = counter + 1'b1;
            end
        end
    end
    // Internal full signal to see if we are actually full
    internal_full = '1;
    for(int i = 0; i < reservation_table_size; i++) begin
        internal_full &= reservation_table[i].rs_entry.full;
    end

    // Table full spec
    if((avail_inst && (32'(counter) == unsigned'(reservation_table_size - 1))) || (32'(counter) == unsigned'(reservation_table_size)))begin
        table_full = 1'b1;
    end
    else begin
        table_full = 1'b0;
    end
end
endmodule : reservation_table