// soumil is slow
// watch the fucking lectures u actual fucking cocksucker
module phys_reg_file
import rv32i_types::*;
#(
    parameter SS = 2, // Superscalar
    parameter TABLE_ENTRIES = 64
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
    
    // Dispatch IO
    input physical_reg_request_t dispatch_request [SS],
    output physical_reg_response_t dispatch_reg_data [SS],

    // ALU Requests 
    input physical_reg_request_t alu_request [N_ALU],
    output physical_reg_response_t alu_reg_data [N_ALU],

    // MUL Requests
    input physical_reg_request_t mul_request [N_MUL],
    output physical_reg_response_t mul_reg_data [N_MUL],

    // LSQ Requests
    input physical_reg_request_t lsq_request,
    output physical_reg_response_t lsq_reg_data
);

    physical_reg_data_t  data [TABLE_ENTRIES];

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < TABLE_ENTRIES; i++) begin
                data[i] <= '0;
            end
        end else if (regf_we) begin
            // Dispatch updates rob dependencies now
            for (int i = 0; i < SS; i++) begin
            // for the given source register, is it NOT R0?
                if(dispatch_request[i].rd_en) begin
                    data[dispatch_request[i].rd_s].ROB_ID <= dispatch_request[i].rd_v.ROB_ID; 
                    data[dispatch_request[i].rd_s].dependency <= '1; 
                end
            end

            // CDB entries 
            for (int i = 0; i < CDB; i++) begin
            // for the given source register, is it NOT R0?
                if(cdb[i].ready_for_writeback && cdb[i].inst_info.rat.rd != '0) begin
                    // When we write via cdb for funct, then we remove ROB_ID because dependency is gone
                    // Due to register-renaming, ROB entries and physical registers are one-to-one. So when dependency is gone, we flush the ROB. 
                    data[cdb[i].inst_info.rat.rd].register_value <= cdb[i].register_value; 
                    data[cdb[i].inst_info.rat.rd].dependency <= '0; 
                end
            end
        end
    end     

    // LSQ Response
    always_comb begin
        for(int i = 0; i < CDB; i++)begin
            // Default RS1
            lsq_reg_data.rs1_v = data[lsq_request.rs1_s];
            if(cdb[i].ready_for_writeback && (lsq_request.rs1_s == cdb[i].inst_info.rat.rd)) begin
                lsq_reg_data.rs1_v.register_value = cdb[i].register_value;
                lsq_reg_data.rs1_v.dependency = ~cdb[i].inst_info.rs_entry.input1_met;
                lsq_reg_data.rs1_v.ROB_ID = cdb[i].inst_info.rob.rob_id;
            end

            // Default RS2
            lsq_reg_data.rs2_v = data[lsq_request.rs2_s];
            if(cdb[i].ready_for_writeback && (lsq_request.rs2_s == cdb[i].inst_info.rat.rd)) begin
                lsq_reg_data.rs2_v.register_value = cdb[i].register_value;
                lsq_reg_data.rs2_v.dependency = ~cdb[i].inst_info.rs_entry.input2_met;
                lsq_reg_data.rs2_v.ROB_ID = cdb[i].inst_info.rob.rob_id;
            end
        end
    end

    // Modifying for the transparent regfile so if we are in the dispatcher
    // and the dispatcher needs to fetch data which is being written by the functional unit(s) then
    // it can get it immediately 
    //
    // Dispatch Response
    always_comb begin
        for(int s = 0; s < SS; s++) begin
            for(int i = 0; i < CDB; i++) begin
                // RS1 Default
                dispatch_reg_data[s].rs1_v = data[dispatch_request[s].rs1_s];
                if(cdb[i].ready_for_writeback && (dispatch_request[s].rs1_s == cdb[i].inst_info.rat.rd)) begin
                    dispatch_reg_data[s].rs1_v.register_value = cdb[i].register_value;
                    dispatch_reg_data[s].rs1_v.dependency = ~cdb[i].inst_info.rs_entry.input1_met;
                    dispatch_reg_data[s].rs1_v.ROB_ID = cdb[i].inst_info.rob.rob_id;
                end

                // RS2 Default
                dispatch_reg_data[s].rs2_v = data[dispatch_request[s].rs2_s];
                if(cdb[i].ready_for_writeback && (dispatch_request[s].rs2_s == cdb[i].inst_info.rat.rd)) begin
                    dispatch_reg_data[s].rs2_v.register_value = cdb[i].register_value;
                    dispatch_reg_data[s].rs2_v.dependency = ~cdb[i].inst_info.rs_entry.input2_met;
                    dispatch_reg_data[s].rs2_v.ROB_ID = cdb[i].inst_info.rob.rob_id;
                end
            end
        end
    end

    // ALU Response
    always_comb begin
        for(int r = 0; r < N_ALU; r++) begin
            for(int i = 0; i < CDB; i++) begin
                // RS1 Default
                alu_reg_data[r].rs1_v = data[alu_request[r].rs1_s];
                if(cdb[i].ready_for_writeback && (alu_request[r].rs1_s == cdb[i].inst_info.rat.rd)) begin
                    alu_reg_data[r].rs1_v.register_value = cdb[i].register_value;
                    alu_reg_data[r].rs1_v.dependency = ~cdb[i].inst_info.rs_entry.input1_met;
                    alu_reg_data[r].rs1_v.ROB_ID = cdb[i].inst_info.rob.rob_id;
                end
                // RS2 Default
                alu_reg_data[r].rs2_v = data[alu_request[r].rs2_s];
                if(cdb[i].ready_for_writeback && (alu_request[r].rs2_s == cdb[i].inst_info.rat.rd)) begin
                    alu_reg_data[r].rs2_v.register_value = cdb[i].register_value;
                    alu_reg_data[r].rs2_v.dependency = ~cdb[i].inst_info.rs_entry.input2_met;
                    alu_reg_data[r].rs2_v.ROB_ID = cdb[i].inst_info.rob.rob_id;
                end
            end
        end
    end

    // MUL Response 
    always_comb begin
        for(int r = 0; r < N_MUL; r++) begin
            for(int i = 0; i < CDB; i++) begin
                // RS1 Default
                mul_reg_data[r].rs1_v = data[mul_request[r].rs1_s];
                if(cdb[i].ready_for_writeback && (mul_request[r].rs1_s == cdb[i].inst_info.rat.rd)) begin
                    mul_reg_data[r].rs1_v.register_value = cdb[i].register_value;
                    mul_reg_data[r].rs1_v.dependency = ~cdb[i].inst_info.rs_entry.input1_met;
                    mul_reg_data[r].rs1_v.ROB_ID = cdb[i].inst_info.rob.rob_id;
                end

                // RS2 Default
                mul_reg_data[r].rs2_v = data[mul_request[r].rs2_s];
                if(cdb[i].ready_for_writeback && (mul_request[r].rs2_s == cdb[i].inst_info.rat.rd)) begin
                    mul_reg_data[r].rs2_v.register_value = cdb[i].register_value;
                    mul_reg_data[r].rs2_v.dependency = ~cdb[i].inst_info.rs_entry.input2_met;
                    mul_reg_data[r].rs2_v.ROB_ID = cdb[i].inst_info.rob.rob_id;
                end
            end
        end
    end

endmodule : phys_reg_file
