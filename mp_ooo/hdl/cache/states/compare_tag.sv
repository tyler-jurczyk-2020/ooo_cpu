module compare_tag 
import cache_types::*;
#(
    parameter               WAYS       = 4,
    parameter               TAG_SIZE   = 24
)
(
    input logic [31:0] set_way,
    input state_t state,
    input logic [TAG_SIZE-2:0] target_tag,
    input logic ways_valid [WAYS],
    input logic [TAG_SIZE-1:0] ways_tags [WAYS],
    input logic [3:0] wmask,
    input logic [4:0] offset,

    output logic valid_hit, dirty,
    output logic [31:0] way_hit,
    output logic [TAG_SIZE-2:0] set_tag,
    output logic [31:0] wb_mask
);


logic valid_hit_way [WAYS];
logic [31:0] way_hit_val, aligned_mask;
assign set_tag = target_tag;
assign dirty = ways_tags[set_way][TAG_SIZE-1];
assign aligned_mask = wmask << {offset[4:2],2'b0};

always_comb begin
    valid_hit = 1'b0;
    way_hit_val = 32'b0;

    for(int i = 0; i < WAYS; i++) begin
        if(ways_valid[i] && ways_tags[i][TAG_SIZE-2:0] == target_tag) begin
            valid_hit_way[i] = 1'b1;
            way_hit_val |= unsigned'(i);
        end
        else begin
            valid_hit_way[i] = 1'b0;
            way_hit_val |= 0;
        end
        valid_hit |= valid_hit_way[i];
    end

    if(valid_hit) begin
        way_hit = way_hit_val;
    end
    else begin
        way_hit = 'x;
    end

    if(valid_hit && state == compare_tag_s && wmask != 4'b0)
        wb_mask = aligned_mask;
    else
        wb_mask = 'x;
end

endmodule : compare_tag
