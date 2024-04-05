module res_table
    import rv32i_types::*;
    #(
        parameter SS = 2,
        parameter reservation_table_size = 8,
        parameter ROB_DEPTH = 7 
    )
    (
        input clk, rst, 

        /////////////// WRITING TO TABLE ///////////////
        // get entry from the dispatcher 
        super_dispatch_t dispatched [SS], 

        // indicates whether dispatched signal is new signal
        logic avail_inst, 


        /////////////// ISSUING FROM TABLE ///////////////
        output fu_input_t to_be_multiplied, // *parameterize!


        /////////////// RETRIEVING UPDATED DEPENDECY FROM FU (CDB) ///////////////
        input cdb_t cdb_rob_ids [SS * FU_COUNT], 

        /////////////// REQUESTING REGISTER VALUE FROM PHYS. REG. FILE ///////////////
        output physical_reg_request_t fu_request,

        /////////////// FU FULL - DON'T ISSUE ///////////////
        input logic fu_full, 
        
        /////////////// STALL DISPATCHING ///////////////
        output table_full 

    );

    // table. Packed array
    super_dispatch_t reservation_table [reservation_table_size]; 

    // Determine for determing whether table is full or not 
    logic [$clog2(reservation_table_size)-1:0] counter; 

    fu_input_t local_inst_fu;  
    assign to_be_multiplied = local_inst_fu;


    // Write to the table 
    always_ff @ (posedge clk) begin
        if(rst) begin
            for(int j = 0; j < reservation_table_size; j++) begin
                reservation_table[j].rs_entry.full <= '0; 
            end
        end
        // Write new entry
        else begin
            if(avail_inst && ~table_full) begin
                for(int i = 0; i < SS; i++) begin
                    for(int j = 0; j < reservation_table_size; j++) begin
                        if(~reservation_table[j].full) begin
                            reservation_table[j] <= dispatched[i]; 
                            reservation_table[j].rs_entry.full <= '1; 
                            // MUST break because otherwise the entry will be put in to every available spot in the table
                            // Go next dispatched instruction
                            break; 
                        end
                    end
                end
            end
        end
        // For a given CDB, Check whether we need to update any of the Entries
        for(int i = 0; i < SS * FU_COUNT; i++) begin
            for(int j = 0; j < reservation_table_size; j++) begin
                if(cdb_rob_ids[i].ready_for_writeback) begin
                    if(reservation_table[j].rs_entry.rs1_source == cdb_rob_ids[i].inst_info.rs_entry.rob_id) begin
                        reservation_table[j].rs_entry.input1_met <= '1; 
                    end
                    if(reservation_table[j].rs_entry.rs2_source == cdb_rob_ids[i].inst_info.rs_entry.rob_id) begin
                        reservation_table[j].rs_entry.input2_met <= '1; 
                    end
                end
                local_inst_fu.start_calculate <= '0; 
                // See whether to issue an entry
                if(reservation_table[j].rs_entry.full && reservation_table[j].rs_entry.input1_met && reservation_table[j].rs_entry.input2_met) begin
                    if(~fu_full) begin
                        reservation_table[j].rs_entry.full <= '0;
                        local_inst_fu.inst_info <= reservation_table[j]; 
                        local_inst_fu.start_calculate <= '1; 
                        if(reservation_table[j].inst.rs1_s != 5'b0) begin
                            fu_request.rs1_s <= reservation_table[j].rat.rs1;
                        end
                        else begin
                            fu_request.rs1_s <= 'x;
                        end
                        if(reservation_table[j].inst.rs2_s != 5'b0) begin
                            fu_request.rs2_s <= reservation_table[j].rat.rs2;
                        end
                        else begin
                            fu_request.rs2_s <= 'x;
                        end
                    end
                end
            end
        end
    end

    
    
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
    
    endmodule : res_table
    