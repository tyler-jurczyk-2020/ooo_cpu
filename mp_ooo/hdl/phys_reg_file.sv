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
    input logic [$clog2(TABLE_ENTRIES)-1:0] rd_s_ROB_write_destination [SS], 
    input logic [$clog2(ROB_DEPTH)-1:0] ROB_ID_ROB_write_destination [SS], 
    
    // We write to the phys reg file also when we have info from the funct. unit
    // This info is passed into the CDB which will set the input signals
    // Only info needed is the raw data for the physical register 
    input [31:0] rd_v_FU_write_destination [SS], 

    // CDB/Reservation exchange
    input fu_output_t cdb [SS],
    output logic [7:0] reservation_rob_id,
    
    // flag to indicate which values we are receiving, as we won't always be overwriting the rd_v specifically
    input logic write_from_fu [SS], 
    input logic write_from_rob [SS], 

    // registers we'd like to read from the phys. reg. file for the dispatcher
    input logic [$clog2(TABLE_ENTRIES)-1:0] rs1_s_dispatch_request [SS], 
    input logic [$clog2(TABLE_ENTRIES)-1:0] rs2_s_dispatch_request [SS], 
    output  physical_reg_data_t source_reg_1 [SS], source_reg_2 [SS],

    input logic [$clog2(TABLE_ENTRIES)-1:0] rs1_s_fu_request [SS], 
    input logic [$clog2(TABLE_ENTRIES)-1:0] rs2_s_fu_request [SS], 
    output  physical_reg_data_t source_reg_1_fu [SS], source_reg_2_fu [SS]
);

    physical_reg_data_t  data [TABLE_ENTRIES];

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < 32; i++) begin
                data[i] <= '0;
            end
        end else if (regf_we) begin
            for (int i = 0; i < SS; i++) begin
                // for the given source register, is it NOT R0?
                for(int j = 0; j < TABLE_ENTRIES; j++) begin
                    if(rd_s_ROB_write_destination[i] != 6'b0) begin
                        if(write_from_fu[i]) begin
                            // When we write via CDB for funct, then we remove ROB_ID because dependency is gone
                            // Due to register-renaming, ROB entries and physical registers are one-to-one. So when dependency is gone, we flush the ROB. 
                            data[j].register_value <= rd_v_FU_write_destination[i]; 
                            data[j].dependency <= '0; 
                        end
                        else if(write_from_rob[i]) begin
                            data[j].ROB_ID <= ROB_ID_ROB_write_destination[i]; 
                            data[j].dependency <= '1; 
                        end
                    end
                end
            end
        end
    end     

    always_comb begin
        for(int i = 0; i < SS; i++) begin
            for(int j = 0; j < TABLE_ENTRIES; j++) begin
                if (write_from_fu[i] && cdb[i].inst_info.reservation_entry.rat.rd == j[5:0]) begin
                    reservation_rob_id = data[j].ROB_ID;
                end   
            end
        end
    end
    // Modifying for the transparent regfile so if we are in the dispatcher
    // and the dispatcher needs to fetch data which is being written by the functional unit(s) then
    // it can get it immediately 
    always_comb begin
        for (int i = 0; i < SS; i++) begin
            if (rs1_s_dispatch_request[i] != 6'd0) begin
                if(write_from_fu[i] && (rs1_s_dispatch_request[i] == rd_s_ROB_write_destination[i])) begin
                    source_reg_1[i].register_value = rd_v_FU_write_destination[i];
                    // Also update reservation station dependencies
                    
                end
                else begin
                    source_reg_1[i] = data[rs1_s_dispatch_request[i]];
                end
            end else begin
                source_reg_1[i] = 'x;
            end    
            if (rs2_s_dispatch_request[i] != 6'd0 && (rs2_s_dispatch_request[i] == rd_s_ROB_write_destination[i])) begin
                if(write_from_fu[i]) begin
                    source_reg_2[i].register_value = rd_v_FU_write_destination[i];
                end
                else begin
                    source_reg_2[i] = data[rs2_s_dispatch_request[i]];
                end
            end else begin
                source_reg_2[i] = 'x;
            end
        end
    end
// bs copy for reading to fu hi
    always_comb begin
        for (int i = 0; i < SS; i++) begin
            if (rs1_s_fu_request[i] != 6'd0) begin
                if(write_from_fu[i] && (rs1_s_fu_request[i] == rd_s_ROB_write_destination[i])) begin
                    source_reg_1_fu[i].register_value = rd_v_FU_write_destination[i];
                end
                else begin
                    source_reg_1_fu[i] = data[rs1_s_fu_request[i]];
                end
            end else begin
                source_reg_1_fu[i] = '0;
            end    
            if (rs2_s_fu_request[i] != 6'd0 && (rs2_s_fu_request[i] == rd_s_ROB_write_destination[i])) begin
                if(write_from_fu[i]) begin
                    source_reg_2_fu[i].register_value = rd_v_FU_write_destination[i];
                end
                else begin
                    source_reg_2_fu[i] = data[rs2_s_fu_request[i]];
                end
            end else begin
                source_reg_2_fu[i] = '0;
            end
        end
    end

endmodule : phys_reg_file
