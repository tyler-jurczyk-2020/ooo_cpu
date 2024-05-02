module retired_rat
import rv32i_types::*;
#(
    parameter SS = 2
)
(
////// INPUTS:
    input logic clk,
    input logic rst,
    // write enable for Retired Rat
    input logic retire_we, 
    // writing random shit rn
    input super_dispatch_t rob_info [SS],
////// OUTPUTS:
    output logic [5:0] free_list_entry [SS],
    output logic push_to_free_list [SS],
    output logic [5:0] backup_retired_rat [32]
    );

logic [5:0] data [32]; // array of rats in the retired rat state

always_comb begin
    backup_retired_rat = data;
    for(int i = 0; i < SS; i++) begin
        if(retire_we && rob_info[i].inst.rd_s != 5'b0) begin
            // update retired rat based on instr's reg mapping
            backup_retired_rat[rob_info[i].inst.rd_s] = rob_info[i].rat.rd;
        end
    end
end

// // NOT CORRECT FOR SS > 1 !!! (It is now get fucked @tealer)
// assign push_to_free_list[0] = retire_we && (rob_info[0].rat.rd != '0);
// assign push_to_free_list[1] = retire_we && (rob_info[1].rat.rd != '0) && (rob_info[0].inst.rd_s != rob_info[1].inst.rd_s);

always_ff @(posedge clk) begin
    for(int i = 0; i < SS; i++) begin
        if (rst) begin
            // reset all the mfing entries
            for(int unsigned i = 0; i < 32; i++) 
                data[i] <= 6'(i);
        end
        else if(retire_we && rob_info[i].inst.rd_s != 5'b0) begin
            // update retired rat based on instr's reg mapping
            data[rob_info[i].inst.rd_s] <= rob_info[i].rat.rd;
        end
    end
end

// Instruction in way 1: 
// Must be valid commit 
// if both way 1 and way 2 are writing to the same ISA reg, then way 1's RAT RD_S must be freed
// otherwise, 
// the ISA RD_S's current architectural mapping must be replaced 
// The current arch. mapping must be replaced with the internal mapping
// The internal reg. by the arch. mapping must go to the free list. 
// we push to free list if not nop

// Instruction in way 2: 
// must be a valid commit (only in theory wouldn't be valid if the first inst is a mispredict or its the .HALT inst)
// the ISA RD_S's current architectural mapping must be replaced 
// The current arch. mapping must be replaced with the internal mapping
// The internal reg. by the arch. mapping must go to the free list. 
// we push to free list if not nop

always_comb begin
    if(retire_we && (rob_info[0].inst.rd_s == rob_info[1].inst.rd_s) && (rob_info[0].inst.rd_s != 5'b0)) begin
        free_list_entry[0] = rob_info[0].rat.rd;
        free_list_entry[1] = data[rob_info[1].inst.rd_s];
    end
    else begin
        free_list_entry[0] = data[rob_info[0].inst.rd_s];
        free_list_entry[1] = data[rob_info[1].inst.rd_s];
    end

    for(int i = 0; i < SS; i++) begin
        push_to_free_list[i] = rob_info[i].rob.commit && (rob_info[i].inst.rd_s != 5'b0) && rob_info[i].inst.has_rd; 
    end

end

endmodule : retired_rat
