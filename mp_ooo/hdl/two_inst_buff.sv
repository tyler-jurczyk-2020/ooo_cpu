module two_inst_buff
import rv32i_types::*;
#(
parameter WIDTH = 32,
parameter DEPTH = 4,
parameter DEPTH_BITS = 2, 
parameter SUPERSCALAR = 2,
parameter SUPERSCALAR_BITS = 1
)
(
    input logic clk, 
    input logic rst, 
    input logic valid, 
    // fk me
    input instruction_info_reg_t decoded_inst,
    output instruction_info_reg_t valid_inst[2],
    output logic valid_out
);

instruction_info_reg_t buffer[2]; 
logic counter; 
logic update_output;

always_ff @ (posedge clk) begin
    if(rst) begin
        buffer[0] <= '0; 
        buffer[1] <= '0;
        counter <= '0;  
    end
    else if (valid) begin
        buffer[counter] <= decoded_inst; 
        counter <= counter + 1'b1; 
    end

    if(counter == 1'b1 && valid)
        valid_out <= 1'b1; 
    else 
        valid_out <= 1'b0;
end

always_comb begin
   if(valid_out) 
       valid_inst = buffer;
   else begin
       for(int i = 0; i < 2; i++) begin
            valid_inst[i] = '0;
       end
   end
end

endmodule : two_inst_buff
