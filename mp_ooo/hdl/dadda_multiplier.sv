module dadda_multiplier
#(
    parameter int OPERAND_WIDTH = 32
)
(
    input logic clk,
    input logic rst,
    input logic start,
    input logic [1:0] mul_type,
    input logic[OPERAND_WIDTH-1:0] a,
    input logic[OPERAND_WIDTH-1:0] b,
    output logic[2*OPERAND_WIDTH-1:0] p,
    output logic done
);

    // Constants for multiplication case readability
    `define UNSIGNED_UNSIGNED_MUL 2'b00
    `define SIGNED_SIGNED_MUL     2'b01
    `define SIGNED_UNSIGNED_MUL   2'b10

    enum int unsigned {IDLE, GENERATE_PP, REDUCE, FINAL_ADD, DONE} curr_state, next_state;
    localparam int OP_WIDTH_LOG = $clog2(OPERAND_WIDTH);
    logic neg_result;
    logic [OPERAND_WIDTH-1:0] product_terms [OPERAND_WIDTH-1:0];
    
    logic [2*OPERAND_WIDTH-1:0] accumulator;
    logic [2*OPERAND_WIDTH-1:0] next_terms[OPERAND_WIDTH/2-1:0]; // Half the rows
        
    // State transitions and state machine management
    always_comb
    begin : state_transition
        next_state = curr_state;
        unique case (curr_state)
            IDLE:    next_state = start ? GENERATE_PP : IDLE;
            GENERATE_PP: next_state = REDUCE;
            REDUCE:  next_state = FINAL_ADD;
            FINAL_ADD: next_state = DONE;
            DONE:    next_state = start ? DONE : IDLE;
            default: next_state = IDLE;
        endcase
    end : state_transition

    // Output logic and calculations
    always_comb
    begin : state_outputs
        done = '0;
        p = '0;
        unique case (curr_state)
            DONE:
            begin
                done = 1'b1;
                unique case (mul_type)
                    `UNSIGNED_UNSIGNED_MUL: p = accumulator;
                    `SIGNED_SIGNED_MUL,
                    `SIGNED_UNSIGNED_MUL: p = neg_result ? (~accumulator + 1'b1) : accumulator;
                    default: ;
                endcase
            end
            default: ;
        endcase
    end : state_outputs

    always_ff @ (posedge clk) begin
        if (rst) begin
            curr_state <= IDLE;
            accumulator <= '0;
            neg_result <= '0;
            for (int i = 0; i < OPERAND_WIDTH; i++)
                product_terms[i] <= '0;
            
        end
        else begin
            curr_state <= next_state;
            unique case (curr_state)
                // aint nothin happenin
                IDLE:
                begin
                    if (start)begin
                        neg_result <= (a[OPERAND_WIDTH-1] ^ b[OPERAND_WIDTH-1]) && mul_type != `UNSIGNED_UNSIGNED_MUL;
                        for (int i = 0; i < OPERAND_WIDTH; i++) begin
                            product_terms[i] <= a & ({OPERAND_WIDTH{b[i]}});
                        end
                    end
                end
                
                // products already generated 
                GENERATE_PP: ;
                
                // tree reduction stage
                REDUCE:
                begin
                    // reducing from 32 rows to 16, then to 8 rows
                    
                    for (int i = 0; i < OPERAND_WIDTH/2; i++) 
                        next_terms[i] = product_terms[2*i] + product_terms[2*i+1]; // Sum pairs of rows
                    
                    for (int i = 0; i < OPERAND_WIDTH/2; i++) begin
                        product_terms[i] = next_terms[i]; // Write back reduced rows
                    end
                    // Zero out the unused terms
                    for (int i = OPERAND_WIDTH/2; i < OPERAND_WIDTH; i++) begin
                        product_terms[i] = '0;
                    end
                end

                FINAL_ADD:
                begin
                    // sum up the produce
                    accumulator <= '0;
                    for (j = 0; j < OPERAND_WIDTH; j++) begin
                        accumulator <= accumulator + product_terms[j];
                    end
                end
                DONE: ;
                default: ;
            endcase
        end
    end

endmodule
