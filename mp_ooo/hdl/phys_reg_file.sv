// soumil is slow
// watch the fucking lectures u actual fucking cocksucker
module phys_reg_file
import rv32i_types::*;
#(
    parameter SS = 2, // Superscalar
    parameter TABLE_ENTRIES = 64,
    parameter ROB_DEPTH = 7
)
(
    input   logic           clk,
    input   logic           rst,
    input   logic           regf_we,

    // We write to the physical register file with the associated ROB
    // when we dispatch a new instruction into the issue stage 
    // ROB ID from the ROB directly

    
    // We write to the phys reg file also when we have info from the funct. unit
    // This info is passed into the cdb which will set the input signals
    // Only info needed is the raw data for the physical register 
    // input [31:0] rd_v_FU_write_destination [SS], 

    // cdb/Reservation exchange
    output logic [7:0] reservation_rob_id [SS * FU_COUNT],
    input cdb_t cdb [SS], 
    
    // ROB IO
    input physical_reg_request_t rob_request [SS],

    // Dispatch IO
    input physical_reg_request_t dispatch_request [SS],
    output physical_reg_response_t dispatch_reg_data [SS],

    // FU IO
    input physical_reg_request_t fu_request [SS],
    output physical_reg_response_t fu_reg_data [SS]
);

    physical_reg_data_t  data [TABLE_ENTRIES];

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < TABLE_ENTRIES; i++) begin
                data[i] <= '0;
            end
        end else if (regf_we) begin
            // NOT ITERATING WAYS, BUT ITERATING THROUGH THE MULTI-BUS CDB
            for (int i = 0; i < SS; i++) begin
                for(int j = 0; j < FU_COUNT; j++) begin
                // for the given source register, is it NOT R0?
                // for(int j = 0; j < TABLE_ENTRIES; j++) begin
                    // if(cdb[i].inst_info.reservation_entry.rat.rd != 6'b0) begin
                        if(cdb[i][j].ready_for_writeback) begin
                            // When we write via cdb for funct, then we remove ROB_ID because dependency is gone
                            // Due to register-renaming, ROB entries and physical registers are one-to-one. So when dependency is gone, we flush the ROB. 
                            data[cdb[i][j].inst_info.reservation_entry.rat.rd].register_value <= cdb[i][j].register_value; 
                            data[cdb[i][j].inst_info.reservation_entry.rat.rd].dependency <= '0; 
                            // break; 
                        end
                        // ROB should not be using CDB !!!
                        else if(rob_request[i].rd_en) begin
                            data[cdb[i][j].inst_info.reservation_entry.rat.rd].ROB_ID <= rob_request[i].rd_s; 
                            data[cdb[i][j].inst_info.reservation_entry.rat.rd].dependency <= '1; 
                            // break; 
                        end
                    // end
                // end
                end
            end
        end
    end     

    always_comb begin
        for(int i = 0; i < SS; i++) begin
            for(int j = 0; j < FU_COUNT; j++) begin
            // for(int j = 0; j < TABLE_ENTRIES; j++) begin
                // if (write_from_fu[i] && cdb[i].inst_info.reservation_entry.rat.rd == j[5:0]) begin
                    reservation_rob_id[i*SS + j] = data[cdb[i][j].inst_info.reservation_entry.rat.rd].ROB_ID;
                // end   
            // end
            end
        end
    end
    // Modifying for the transparent regfile so if we are in the dispatcher
    // and the dispatcher needs to fetch data which is being written by the functional unit(s) then
    // it can get it immediately 
    //
    // Request from dispatch
    always_comb begin
        for (int i = 0; i < SS; i++) begin
            for(int j = 0; j < FU_COUNT; j++) begin
                if(cdb[i][j].ready_for_writeback && (dispatch_request[i].rs1_s == cdb[i][j].inst_info.reservation_entry.rat.rd)) begin
                    dispatch_reg_data[i].rs1_v = cdb[i][j].register_value;
                end
                else begin
                    dispatch_reg_data[i].rs1_v = data[dispatch_request[i].rs1_s];
                end

                if(cdb[i][j].ready_for_writeback && (dispatch_request[i].rs2_s == cdb[i][j].inst_info.reservation_entry.rat.rd)) begin
                    dispatch_reg_data[i].rs2_v = cdb[i][j].register_value;
                end
                else begin
                    dispatch_reg_data[i].rs2_v = data[dispatch_request[i].rs2_s];
                end
            end
        end
    end

    // Also supports transparency
    // Request in reservation station and read output in fu
    always_comb begin
        for (int i = 0; i < SS; i++) begin
            for(int j = 0; j < FU_COUNT; j++) begin
                if(cdb[i][j].ready_for_writeback && (fu_request[i].rs1_s == cdb[i][j].inst_info.reservation_entry.rat.rd)) begin
                    fu_reg_data[i].rs1_v = cdb[i][j].register_value;
                end
                else begin
                    fu_reg_data[i].rs1_v = data[fu_request[i].rs1_s];
                end

                if(cdb[i][j].ready_for_writeback && (fu_request[i].rs2_s == cdb[i][j].inst_info.reservation_entry.rat.rd)) begin
                    fu_reg_data[i].rs2_v = cdb[i][j].register_value;
                end
                else begin
                    fu_reg_data[i].rs2_v = data[dispatch_request[i].rs1_s];
                end
            end
        end
    end

endmodule : phys_reg_file
