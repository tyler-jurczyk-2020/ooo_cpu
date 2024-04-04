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
    // the write destination is provided by the dispatcher
    // The ROB_ID is provided preemptively by the ROB_ID so writing ROB_ID
    // happens at the same time dispatcher runs
    input logic [$clog2(TABLE_ENTRIES)-1:0] rd_s_ROB_write_destination [SS], 
    input logic [$clog2(ROB_DEPTH)-1:0] ROB_ID_for_new_inst [SS], 
    
    // We write to the phys reg file also when we have info from the funct. unit
    // This info is passed into the cdb which will set the input signals
    // Only info needed is the raw data for the physical register 
    // input [31:0] rd_v_FU_write_destination [SS], 

    // cdb/Reservation exchange
    // The CDB provides a updated PR Value and this wire here gets updated with 
    // the ROB_ID which is now satisfied due to this which is sent to the reservation
    // station to inform that this dependency is resolved 
    // output logic [7:0] reservation_rob_id [SS],
    input fu_output_t cdb [SS], 
    
    // flag to indicate which values we are receiving, as we won't always be overwriting the rd_v specifically
    // Both could be high at the same time
    input logic write_from_fu [SS], 
    input logic write_from_rob [SS], 

    // registers we'd like to read from the phys. reg. file for the dispatcher
    input logic [$clog2(TABLE_ENTRIES)-1:0] rs1_s_dispatch_request [SS], 
    input logic [$clog2(TABLE_ENTRIES)-1:0] rs2_s_dispatch_request [SS], 
    output  physical_reg_data_t source_reg_1 [SS], source_reg_2 [SS],

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
                // for the given source register, is it NOT R0?
                // for(int j = 0; j < TABLE_ENTRIES; j++) begin
                    // if(cdb[i].inst_info.reservation_entry.rat.rd != 6'b0) begin
                        if(write_from_fu[i]) begin
                            // When we write via cdb for funct, then we remove ROB_ID because dependency is gone
                            // Due to register-renaming, ROB entries and physical registers are one-to-one. So when dependency is gone, we flush the ROB. 
                            data[cdb[i].inst_info.reservation_entry.rat.rd].register_value <= cdb[i].register_value; 
                            data[cdb[i].inst_info.reservation_entry.rat.rd].dependency <= '0; 
                            // break; 
                        end
                        if(write_from_rob[i]) begin
                            data[rd_s_ROB_write_destination[i]].ROB_ID <= ROB_ID_for_new_inst[i]; 
                            data[rd_s_ROB_write_destination[i]].dependency <= '1; 
                            // break; 
                        end
                    // end
                // end
            end
        end
    end     

    // always_comb begin
    //     for(int i = 0; i < SS; i++) begin
    //         // for(int j = 0; j < TABLE_ENTRIES; j++) begin
    //             // if (write_from_fu[i] && cdb[i].inst_info.reservation_entry.rat.rd == j[5:0]) begin
    //                 reservation_rob_id[i] = data[cdb[i].inst_info.reservation_entry.rat.rd].ROB_ID;
    //             // end   
    //         // end
    //     end
    // end
    // Modifying for the transparent regfile so if we are in the dispatcher
    // and the dispatcher needs to fetch data which is being written by the functional unit(s) then
    // it can get it immediately 
    always_comb begin
        for (int i = 0; i < SS; i++) begin
            // if(write_from_fu[i] && (rs1_s_dispatch_request[i] == cdb[i].inst_info.reservation_entry.rat.rd)) begin
            //     source_reg_1[i].register_value = cdb[i].register_value;
            // end
            // else begin
                source_reg_1[i] = data[rs1_s_dispatch_request[i]];
            // end
            // if(write_from_fu[i] && (rs2_s_dispatch_request[i] == cdb[i].inst_info.reservation_entry.rat.rd)) begin
            //     source_reg_2[i].register_value = cdb[i].register_value;
            // end
            // else begin
                source_reg_2[i] = data[rs2_s_dispatch_request[i]];
            // end
            
        end
    end

    // Request in reservation station and read output in fu
    always_comb begin
        for (int i = 0; i < SS; i++) begin
            if(fu_request[i].rs1_en) begin
                fu_reg_data[i].rs1_v = data[fu_request[i].rs1_s];
            end
            else begin
                fu_reg_data[i].rs1_v = 'x;
            end
            if (fu_request[i].rs2_en) begin
                fu_reg_data[i].rs2_v = data[fu_request[i].rs2_s];
            end
            else begin
                fu_reg_data[i].rs2_v = 'x;
            end
        end
    end

endmodule : phys_reg_file
