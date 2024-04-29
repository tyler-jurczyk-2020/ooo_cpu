module reservation_table_div
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

    super_dispatch_t reservation_table_next [reservation_table_size]; 
    logic full_copy [reservation_table_size]; // update combinationally 

    logic table_bitmap [reservation_table_size]; 
    // logic table_bitmap_way1_way2 [reservation_table_size]; 
    // logic table_bitmap_way2_way1 [reservation_table_size]; 


    // Determine for determing whether table is full or not 
    logic [$clog2(reservation_table_size):0] counter; 

    // Write dispached entry into res table
        // res table next gets updated with the dispatched entry combinationally
        // res table gets res table next on clock cycle
    // Preferably if entry is already good for FUs, can try sending out same cycle to an available FU
        // populate with res table next when ready on clock cycle
    // Write from CDB into res table
        // clocked update
    // Preferably if CDB causes entry(s) to become ready for FUs, it can get out same cycle we write to res table

    // cycle 0: get inst from dispatch -> gets into res table next
    // cycle 1: res table gets inst from res table next
    // cycle 2: inst_for_fu0 gets inst
    // cycle 3: issued inst. 

    // futher considerations is if inst is ready from the dispach, 4 cycles at least are lost
    // CDB update still will take a while to issue if it makes inst ready for fu 


    always_comb begin
        reservation_table_next = reservation_table; 
        if(avail_inst && ~internal_full) begin
            for(int i = 0; i < SS; i++) begin
                for(int j = 0; j < reservation_table_size; j++) begin
                    // Need to check to make sure we dont put any loads and stores in the table
                    if(~reservation_table[j].rs_entry.full && (dispatched[i].inst.is_mul == TABLE_TYPE)
                       && dispatched[i].inst.rmask == 4'b0 && dispatched[i].inst.wmask == 4'b0 && (i == 0 || table_bitmap[j] == '0)) begin
                        reservation_table_next[j] = dispatched[i]; 
                        reservation_table_next[j].rs_entry.full = '1; 
                        // MUST break because otherwise the entry will be put in to every available spot in the table
                        // Go next dispatched instruction
                        break;
                    end
                end
            end
        end
        for(int i = 0; i < CDB; i++) begin
            for(int j = 0; j < reservation_table_size; j++) begin
                if(reservation_table[j].rs_entry.full && cdb_rob_ids[i].ready_for_writeback && reservation_table[j].rs_entry.rs1_source == cdb_rob_ids[i].inst_info.rob.rob_id) begin
                    reservation_table_next[j].rs_entry.input1_met = '1; 
                end

                if(reservation_table[j].rs_entry.full && cdb_rob_ids[i].ready_for_writeback && reservation_table[j].rs_entry.rs2_source == cdb_rob_ids[i].inst_info.rob.rob_id) begin
                    reservation_table_next[j].rs_entry.input2_met = '1; 
                end
            end
        end
    end

    always_comb begin
        for(int i = 0; i < REQUEST; i++) begin
            inst_for_fu0[i] = '0; 
            fu_request0[i] = '0; 
        end
        for(int j = 0; j < reservation_table_size; j++) begin
            // table_bitmap_way1_way2[j] = '0;
            full_copy[j] = reservation_table_next[j].rs_entry.full;
        end
        for(int i = 0; i < REQUEST; i++) begin
            for(int j = 0; j < reservation_table_size; j++) begin
                // Flipped both of the for loops in order to not to assign both 
                if(reservation_table[j].rs_entry.full && reservation_table[j].rs_entry.input1_met && reservation_table[j].rs_entry.input2_met) begin
                    // if the entry is ready to be released, check whether its a signed value and whether the signed divider is available
                    if(FU_Ready[i] && (
                        ((i == 0) && (reservation_table[j].inst.div_type == 2'd0 || reservation_table[j].inst.div_type == 2'd2)) || 
                        ((i == 1) && (reservation_table[j].inst.div_type == 2'd1 || reservation_table[j].inst.div_type == 2'd3)))) begin
                        // reservation_table[j].rs_entry.full <= '0;
                        inst_for_fu0[i].inst_info = reservation_table[j]; 
                        inst_for_fu0[i].start_calculate = '1; 
                        fu_request0[i].rs1_s = reservation_table[j].rat.rs1;
                        fu_request0[i].rs2_s = reservation_table[j].rat.rs2;
                        inst_for_fu0[i].inst_info.rob.commit = '1; 
                        full_copy[j] = '0; 
                        break; 
                    end
                end
                else begin
                    inst_for_fu0[i].start_calculate = '0; 
                end
            end
        end
    end

    always_comb begin
        for(int j = 0; j < reservation_table_size; j++) begin
            table_bitmap[j] = '0; 
        end
        if(avail_inst && ~internal_full) begin
            for(int i = 0; i < SS; i++) begin
                for(int j = 0; j < reservation_table_size; j++) begin
                    table_bitmap[j] = '0; 
                    // Need to check to make sure we dont put any loads and stores in the table
                    if(~reservation_table[j].rs_entry.full && (dispatched[i].inst.is_mul == TABLE_TYPE)
                       && dispatched[i].inst.rmask == 4'b0 && dispatched[i].inst.wmask == 4'b0) begin
                        table_bitmap[j] = '1; 
                        break;
                    end
                end
            end
        end
    end

    always_ff @ (posedge clk) begin
        if(rst) begin
            for(int j = 0; j < reservation_table_size; j++) begin
                reservation_table[j].rs_entry.full <= '0; 
            end   
            for(int i = 0; i < REQUEST; i++) begin
                inst_for_fu[i] <= '0; 
                fu_request[i] <= '0; 
            end       
        end
        // Write new entry
        else begin
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
            for(int j = 0; j < reservation_table_size; j++) begin
                reservation_table[j] <= reservation_table_next[j];
                reservation_table[j].rs_entry.full <= full_copy[j];
            end
            inst_for_fu <= inst_for_fu0; 
            fu_request <= fu_request0; 
        end
    end
    
    // Write to the table 
    // always_ff @(posedge clk) begin
    //     if(rst) begin
    //         for(int j = 0; j < reservation_table_size; j++) begin
    //             reservation_table[j].rs_entry.full <= '0; 
    //         end          
    //     end
    //     // Write new entry
    //     else begin
    //         if(avail_inst && ~internal_full) begin
    //             for(int i = 0; i < SS; i++) begin
    //                 for(int j = 0; j < reservation_table_size; j++) begin
    //                     // Need to check to make sure we dont put any loads and stores in the table
    //                     if(~reservation_table[j].rs_entry.full && (dispatched[i].inst.is_mul == TABLE_TYPE)
    //                        && dispatched[i].inst.rmask == 4'b0 && dispatched[i].inst.wmask == 4'b0 && (i == 0 || table_bitmap[j] == '0)) begin
    //                         reservation_table[j] <= dispatched[i]; 
    //                         reservation_table[j].rs_entry.full <= '1; 
    //                         // MUST break because otherwise the entry will be put in to every available spot in the table
    //                         // Go next dispatched instruction
    //                         break;
    //                     end
    //                 end
    //             end
    //         end
    //         // For a given CDB, Check whether we need to update any of the Entries
    //         for(int i = 0; i < CDB; i++) begin
    //             for(int j = 0; j < reservation_table_size; j++) begin
    //                 if(reservation_table[j].rs_entry.full && cdb_rob_ids[i].ready_for_writeback && reservation_table[j].rs_entry.rs1_source == cdb_rob_ids[i].inst_info.rob.rob_id) begin
    //                     reservation_table[j].rs_entry.input1_met <= '1; 
    //                 end

    //                 if(reservation_table[j].rs_entry.full && cdb_rob_ids[i].ready_for_writeback && reservation_table[j].rs_entry.rs2_source == cdb_rob_ids[i].inst_info.rob.rob_id) begin
    //                     reservation_table[j].rs_entry.input2_met <= '1; 
    //                 end
    //             end
    //         end
            // for(int i = 0; i < REQUEST; i++) begin
            //     for(int j = 0; j < reservation_table_size; j++) begin
            //         if(reservation_table[j].rs_entry.full && reservation_table[j].rs_entry.input1_met && reservation_table[j].rs_entry.input2_met) begin
            //             if(FU_Ready[i]) begin
            //                 reservation_table[j].rs_entry.full <= '0;
            //                 // inst_for_fu0[i].inst_info <= reservation_table[j]; 
            //                 // inst_for_fu0[i].start_calculate <= '1; 
            //                 // fu_request0[i].rs1_s <= reservation_table[j].rat.rs1;
            //                 // fu_request0[i].rs2_s <= reservation_table[j].rat.rs2;
            //                 // inst_for_fu0[i].inst_info.rob.commit <= '1; 
            //                 break;
            //             end
            //         end
            //         // else begin
            //         //     inst_for_fu0[i].start_calculate <= '0; 
            //         // end
            //     end
            // end
    //     end
    // end



    // for the previous issue, if an instruction was sent, it can't be sent again 
    // it should generally be fine, but if we dispatched something in way 2 previously, we can't dispatch it again
    // so if we're at i == 1, then mark in a second (third) bitmap that we have deployed this 
    // if we're at i == 0, an entry is off limits if the second bitmap is high for that entry
    // 


    // always_comb begin
    //     for(int i = 0; i < REQUEST; i++) begin
    //         inst_for_fu0[i] = '0; 
    //         fu_request0[i] = '0; 
    //     end
    //     for(int j = 0; j < reservation_table_size; j++) begin
    //         table_bitmap_way1_way2[j] = '0;
    //         // full copy initialize to 0 
    //     end
    //     for(int i = 0; i < REQUEST; i++) begin
    //         for(int j = 0; j < reservation_table_size; j++) begin
    //             // Flipped both of the for loops in order to not to assign both 
    //             if(reservation_table[j].rs_entry.full && reservation_table[j].rs_entry.input1_met && reservation_table[j].rs_entry.input2_met && ~table_bitmap_way1_way2[j]) begin
    //                 if(FU_Ready[i]) begin 
    //                     inst_for_fu0[i].inst_info = reservation_table[j]; 
    //                     inst_for_fu0[i].start_calculate = '1; 
    //                     fu_request0[i].rs1_s = reservation_table[j].rat.rs1;
    //                     fu_request0[i].rs2_s = reservation_table[j].rat.rs2;
    //                     inst_for_fu0[i].inst_info.rob.commit = '1; 
    //                     table_bitmap_way1_way2[j] = '1; 
    //                     break;
    //                 end
    //             end
    //             else begin
    //                 inst_for_fu0[i].start_calculate = '0; 
    //             end
    //         end
    //     end
    // end

    // have same thing for full signal 







always_comb begin
    // Number of occupied entries in the table
    counter = '0;
    // for(int i = 0; i < SS; i++) begin
        for(int j = 0; j < reservation_table_size; j++) begin
            if(reservation_table[j].rs_entry.full) begin
                counter = counter + 1'b1;
            end
        end
    // end
    // Internal full signal to see if we are actually full
    internal_full = '1;
    for(int i = 0; i < reservation_table_size; i++) begin
        internal_full &= reservation_table[i].rs_entry.full;
    end

    // Table full spec
    if((avail_inst && (32'(counter) == unsigned'(reservation_table_size - SS))) || (32'(counter) == unsigned'(reservation_table_size)))begin
        table_full = 1'b1;
    end
    else begin
        table_full = 1'b0;
    end
end
endmodule : reservation_table_div