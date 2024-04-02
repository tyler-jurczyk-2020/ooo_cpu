module two_inst_buff
import rv32i_types::*;
#(
    parameter SS = 2
)
(
    input logic clk, 
    input logic rst, 
    input logic valid, 
    // fk me
    input instruction_info_reg_t decoded_inst,
    output instruction_info_reg_t valid_inst[SS],
    output logic valid_out
);
// Following module only guarenteed to work for one and two way SS
instruction_info_reg_t buffer[2]; 
logic counter; 
logic update_output;

always_ff @ (posedge clk) begin
    if(rst) begin
        for(int i = 0; i < SS; i++)
            buffer[i] <= '0; 
        counter <= '0;  
    end
    else if (valid) begin
        buffer[counter] <= decoded_inst; 
        if(SS == 2)
            counter <= counter + 1'b1; 
    end

    if(counter == 1'b1 && valid && SS == 2)
        valid_out <= 1'b1; 
    else if(counter == 1'b0 && valid && SS == 1)
        valid_out <= 1'b1;
    else 
        valid_out <= 1'b0;
end

always_comb begin
    // Flip order of instructions to ensure correct order in instruction queue
    if(valid_out) begin
        for(int i = 0; i < SS; i++) begin
            valid_inst[i] = buffer[i];
        end
   end
   else begin
       for(int i = 0; i < SS; i++) begin
            valid_inst[i] = 'x;
       end
   end
end

endmodule : two_inst_buff
