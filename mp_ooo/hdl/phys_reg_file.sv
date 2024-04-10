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
    input cdb_t cdb, 
    
    // ROB IO
    input physical_reg_request_t rob_request [SS],

    // Dispatch IO
    input physical_reg_request_t dispatch_request [SS],
    output physical_reg_response_t dispatch_reg_data [SS],

    // ALU Requests 
    input physical_reg_request_t alu_request [N_ALU],
    output physical_reg_response_t alu_reg_data [N_ALU],

    // MUL Requests
    input physical_reg_request_t mul_request [N_MUL],
    output physical_reg_response_t mul_reg_data [N_MUL]
);

    physical_reg_data_t  data [TABLE_ENTRIES];

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < TABLE_ENTRIES; i++) begin
                data[i] <= '0;
            end
        end else if (regf_we) begin
            // ROB
            for (int i = 0; i < SS; i++) begin
            // for the given source register, is it NOT R0?
                if(rob_request[i].rd_en) begin
                    data[rob_request[i].rd_s].ROB_ID <= rob_request[i].rd_v.ROB_ID; 
                    data[rob_request[i].rd_s].dependency <= '1; 
                end
            end

            // ALU
            for (int i = 0; i < N_ALU; i++) begin
            // for the given source register, is it NOT R0?
                if(cdb.alu_out[i].ready_for_writeback) begin
                    // When we write via cdb for funct, then we remove ROB_ID because dependency is gone
                    // Due to register-renaming, ROB entries and physical registers are one-to-one. So when dependency is gone, we flush the ROB. 
                    data[cdb.alu_out[i].inst_info.rat.rd].register_value <= cdb.alu_out[i].register_value; 
                    data[cdb.alu_out[i].inst_info.rat.rd].dependency <= '0; 
                end
            end

            // MUL 
            for (int i = 0; i < N_MUL; i++) begin
            // for the given source register, is it NOT R0?
                if(cdb.mul_out[i].ready_for_writeback) begin
                    // When we write via cdb for funct, then we remove ROB_ID because dependency is gone
                    // Due to register-renaming, ROB entries and physical registers are one-to-one. So when dependency is gone, we flush the ROB. 
                    data[cdb.mul_out[i].inst_info.rat.rd].register_value <= cdb.mul_out[i].register_value; 
                    data[cdb.mul_out[i].inst_info.rat.rd].dependency <= '0; 
                end
            end
        end
    end     


    // Modifying for the transparent regfile so if we are in the dispatcher
    // and the dispatcher needs to fetch data which is being written by the functional unit(s) then
    // it can get it immediately 
    //
    // Request from dispatch
    always_comb begin
        // ALU dispatch
        for (int i = 0; i < N_ALU; i++) begin
            if(cdb.alu_out[i].ready_for_writeback && (dispatch_request[i].rs1_s == cdb.alu_out[i].inst_info.rat.rd)) begin
                dispatch_reg_data[i].rs1_v.register_value = cdb.alu_out[i].register_value;
                dispatch_reg_data[i].rs1_v.dependency = ~cdb.alu_out[i].inst_info.rs_entry.input1_met;
                dispatch_reg_data[i].rs1_v.ROB_ID = cdb.alu_out[i].inst_info.rob.rob_id;
            end
            else begin
                dispatch_reg_data[i].rs1_v = data[dispatch_request[i].rs1_s];
            end

            if(cdb.alu_out[i].ready_for_writeback && (dispatch_request[i].rs2_s == cdb.alu_out[i].inst_info.rat.rd)) begin
                dispatch_reg_data[i].rs2_v.register_value = cdb.alu_out[i].register_value;
                dispatch_reg_data[i].rs2_v.dependency = ~cdb.alu_out[i].inst_info.rs_entry.input2_met;
                dispatch_reg_data[i].rs2_v.ROB_ID = cdb.alu_out[i].inst_info.rob.rob_id;
            end
            else begin
                dispatch_reg_data[i].rs2_v = data[dispatch_request[i].rs2_s];
            end
        end

        // MUL Dispatch
        for (int i = 0; i < N_ALU; i++) begin
            if(cdb.mul_out[i].ready_for_writeback && (dispatch_request[i].rs1_s == cdb.mul_out[i].inst_info.rat.rd)) begin
                dispatch_reg_data[i].rs1_v.register_value = cdb.mul_out[i].register_value;
                dispatch_reg_data[i].rs1_v.dependency = ~cdb.mul_out[i].inst_info.rs_entry.input1_met;
                dispatch_reg_data[i].rs1_v.ROB_ID = cdb.mul_out[i].inst_info.rob.rob_id;
            end
            else begin
                dispatch_reg_data[i].rs1_v = data[dispatch_request[i].rs1_s];
            end

            if(cdb.mul_out[i].ready_for_writeback && (dispatch_request[i].rs2_s == cdb.mul_out[i].inst_info.rat.rd)) begin
                dispatch_reg_data[i].rs2_v.register_value = cdb.mul_out[i].register_value;
                dispatch_reg_data[i].rs2_v.dependency = ~cdb.mul_out[i].inst_info.rs_entry.input2_met;
                dispatch_reg_data[i].rs2_v.ROB_ID = cdb.mul_out[i].inst_info.rob.rob_id;
            end
            else begin
                dispatch_reg_data[i].rs2_v = data[dispatch_request[i].rs2_s];
            end
        end   
    end

    // Also supports transparency
    // ALU Requests 
    always_comb begin
        for (int i = 0; i < N_ALU; i++) begin
            for(int j = 0; j < N_ALU; j++) begin
                if(cdb.alu_out[i].ready_for_writeback && (alu_request[j].rs1_s == cdb.alu_out[i].inst_info.rat.rd)) begin
                    alu_reg_data[j].rs1_v.register_value = cdb.alu_out[i].register_value;
                    alu_reg_data[j].rs1_v.dependency = ~cdb.alu_out[i].inst_info.rs_entry.input1_met;
                    alu_reg_data[j].rs1_v.ROB_ID = cdb.alu_out[i].inst_info.rob.rob_id;
                end
                else begin
                    alu_reg_data[j].rs1_v = data[alu_request[j].rs1_s];
                end

                if(cdb.alu_out[i].ready_for_writeback && (alu_request[j].rs2_s == cdb.alu_out[i].inst_info.rat.rd)) begin
                    alu_reg_data[j].rs2_v.register_value = cdb.alu_out[i].register_value;
                    alu_reg_data[j].rs2_v.dependency = ~cdb.alu_out[i].inst_info.rs_entry.input2_met;
                    alu_reg_data[j].rs2_v.ROB_ID = cdb.alu_out[i].inst_info.rob.rob_id;
                end
                else begin
                    alu_reg_data[j].rs2_v = data[alu_request[j].rs2_s];
                end
            end
        end
    end

    // Reading out 
    // MUL Requests
    always_comb begin
        for (int i = 0; i < N_MUL; i++) begin
            for(int j = 0; j < N_MUL; j++) begin
                if(cdb.mul_out[i].ready_for_writeback && (mul_request[j].rs1_s == cdb.mul_out[i].inst_info.rat.rd)) begin
                    mul_reg_data[j].rs1_v.register_value = cdb.mul_out[i].register_value;
                    mul_reg_data[j].rs1_v.dependency = ~cdb.mul_out[i].inst_info.rs_entry.input1_met;
                    mul_reg_data[j].rs1_v.ROB_ID = cdb.mul_out[i].inst_info.rob.rob_id;
                end
                else begin
                    mul_reg_data[j].rs1_v = data[mul_request[j].rs1_s];
                end

                if(cdb.mul_out[i].ready_for_writeback && (mul_request[j].rs2_s == cdb.mul_out[i].inst_info.rat.rd)) begin
                    mul_reg_data[j].rs2_v.register_value = cdb.mul_out[i].register_value;
                    mul_reg_data[j].rs2_v.dependency = ~cdb.mul_out[i].inst_info.rs_entry.input2_met;
                    mul_reg_data[j].rs2_v.ROB_ID = cdb.mul_out[i].inst_info.rob.rob_id;
                end
                else begin
                    mul_reg_data[j].rs2_v = data[mul_request[j].rs2_s];
                end
            end
        end
    end

endmodule : phys_reg_file
