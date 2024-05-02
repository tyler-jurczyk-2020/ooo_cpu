module inst_plru
import cache_types::*;
(
    input logic [2:0] plru_bits,
    input logic [31:0] way_hit,
    input logic update_plru,
    input state_t state,
    input prefetch_rvalid,
    input logic [31:0] set_way,

    output logic [2:0] set_plru_bits,
    output logic plru_we,
    output way_t set_way_enum
);

assign plru_we = ~update_plru;

// PLRU bits to set upon update
always_comb begin
    if(state == idle_s && prefetch_rvalid) begin
        unique case(set_way)
            0: set_plru_bits = { plru_bits[2], 2'b00 };
            1: set_plru_bits = { plru_bits[2], 2'b10 };
            2: set_plru_bits = { 1'b0, plru_bits[1], 1'b1 };
            3: set_plru_bits = { 1'b1, plru_bits[1], 1'b1 };
            default: set_plru_bits = 'x;
        endcase
    end
    else begin
        unique case(way_hit)
            0: set_plru_bits = { plru_bits[2], 2'b00 };
            1: set_plru_bits = { plru_bits[2], 2'b10 };
            2: set_plru_bits = { 1'b0, plru_bits[1], 1'b1 };
            3: set_plru_bits = { 1'b1, plru_bits[1], 1'b1 };
            default: set_plru_bits = 'x;
        endcase
    end
end

// Determine plru to update if necessary
always_comb begin
    unique case(plru_bits[0])
        // Go right in bit tree
        1'b0: begin
            unique case(plru_bits[2]) 
                1'b0: set_way_enum = D;
                1'b1: set_way_enum = C;
                default: set_way_enum = F;
            endcase
        end
        // Go left in bit tree
        1'b1: begin
            unique case(plru_bits[1])
                1'b0: set_way_enum = B;
                1'b1: set_way_enum = A;
                default: set_way_enum = F;
            endcase
        end
        default: set_way_enum = F;
    endcase
end

endmodule : inst_plru
