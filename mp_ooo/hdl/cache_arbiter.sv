module cache_arbiter

#(
    parameter SS = 2
)
(
    input logic clk, rst,
    
    // Banked memory
    output  logic   [31:0]  bmem_itf_addr,
    output  logic           bmem_itf_read,
    output  logic           bmem_itf_write,
    output  logic   [63:0]  bmem_itf_wdata,
    input   logic           bmem_itf_ready,

    input   logic   [63:0]  bmem_itf_rdata,
    input   logic   [31:0]  bmem_itf_raddr,
    input   logic           bmem_itf_rvalid,

    // Data Memory
    input  logic    [31:0]   dmem_itf_addr,
    input  logic             dmem_itf_rmask,
    input  logic    [3:0]    dmem_itf_wmask,
    output logic    [31:0]   dmem_itf_rdata,
    input  logic    [31:0]   dmem_itf_wdata,
    output logic             dmem_itf_resp,

    // Instruction Memory
    input  logic    [31:0]   imem_itf_addr,
    input  logic             imem_itf_rmask,
    output logic    [(32*SS)-1:0]  imem_itf_rdata,
    output logic             imem_itf_resp

);

// banked mem model for instructions
logic   [31:0]      instr_bmem_addr;
logic               instr_bmem_read;
logic               instr_bmem_write;
logic   [255:0]      instr_bmem_wdata;
logic   [255:0]      instr_bmem_rdata;
logic               instr_bmem_rvalid;

// banked mem model for data
logic   [31:0]      data_bmem_addr;
logic               data_bmem_read;
logic               data_bmem_write;
logic   [255:0]      data_bmem_wdata;
logic   [255:0]      data_bmem_rdata;
logic               data_bmem_rvalid;

// Mux select dfp_resp on data cache
logic dmem_resp_from_bmem;
logic [31:0] dmem_writeback_addr;

cache #(.READ_SIZE(32*SS), .OFFSET(3)) inst_cache
(
    .clk(clk),
    .rst(rst),

    .ufp_addr(imem_itf_addr),
    .ufp_rmask(imem_itf_rmask),
    .ufp_wmask('0),
    .ufp_rdata(imem_itf_rdata),
    .ufp_wdata('x),
    .ufp_resp(imem_itf_resp),

    .dfp_addr(instr_bmem_addr),
    .dfp_read(instr_bmem_read),
    .dfp_write(instr_bmem_write),
    .dfp_rdata(instr_bmem_rdata),
    .dfp_wdata(instr_bmem_wdata),
    .dfp_resp(instr_bmem_rvalid)
);

cache data_cache
(
    .clk(clk),
    .rst(rst),

    .ufp_addr(dmem_itf_addr),
    .ufp_rmask(dmem_itf_rmask),
    .ufp_wmask(dmem_itf_wmask),
    .ufp_rdata(dmem_itf_rdata),
    .ufp_wdata(dmem_itf_wdata),
    .ufp_resp(dmem_itf_resp),

    .dfp_addr(data_bmem_addr),
    .dfp_read(data_bmem_read),
    .dfp_write(data_bmem_write),
    .dfp_rdata(data_bmem_rdata),
    .dfp_wdata(data_bmem_wdata),
    .dfp_resp(dmem_resp_from_bmem)
);

logic [63:0] read_dword_buffer [3], write_dword_buffer [3]; // No need to buffer fourth entry since we can forward it immediately
logic [2:0] read_counter, write_counter;
logic is_writing;
logic inst_request;
logic data_request;
logic latch_data_bmem;
logic   [31:0]      data_bmem_addr_reg;
logic               data_bmem_read_reg;
logic               data_bmem_write_reg;
logic simultaneous_requests;

assign simultaneous_requests = inst_request && data_request;

always_ff @(posedge clk)begin
    if(rst) begin
        read_counter <= '0;
        write_counter <= '0;
        is_writing <= '0;
        dmem_writeback_addr <= '0;
    end
    else begin
        if(bmem_itf_rvalid && read_counter < 3'h3) begin
            read_counter <= read_counter + 1'd1;
            read_dword_buffer[read_counter] <= bmem_itf_rdata;
        end
        else begin
            read_counter <= '0;
        end

        if((data_bmem_write && ~simultaneous_requests) || (latch_data_bmem && data_bmem_write_reg)) begin
            is_writing <= 1'b1;
            dmem_writeback_addr <= data_bmem_addr;
            write_counter <= write_counter + 1'd1;
            for(int i = 0; i < 3; i++) begin // can forward first entry immediately
                write_dword_buffer[i] <= data_bmem_wdata[64*(i+1)+:64];
            end
        end
        else if(write_counter !='0 && write_counter <= 3'h3) begin
            if(write_counter == 3'h3) begin
                is_writing <= '0;
                write_counter <= '0;
            end
            else
                write_counter <= write_counter + 1'b1;
        end
        else begin
            write_counter <= '0;
        end
    end
end

logic delayed_inst_request;

assign inst_request = instr_bmem_read;
assign data_request = data_bmem_read || data_bmem_write;

always_ff @(posedge clk)begin
    if(rst) begin
        delayed_inst_request <= 1'b0;
    end
    else begin
        latch_data_bmem <= inst_request && data_request;
        if(inst_request && data_request) begin
            data_bmem_addr_reg <= data_bmem_addr;
            data_bmem_read_reg <= data_bmem_read;
            data_bmem_write_reg <= data_bmem_write;
        end
        if(inst_request && is_writing) begin
            delayed_inst_request <= 1'b1;
        end
        else if(~is_writing) begin
            delayed_inst_request <= 1'b0;
        end
    end
end

// Implement address table once cache can take more than one request
// MSB is valid, next MSB is 0 if instruction or 1 if data
logic [33:0] address_table [16];

// Update address table entry 
always_ff @(posedge clk) begin
    if(rst)begin
        for(int i = 0; i < 16; i++)begin
            address_table[i] <= '0;
        end
    end
    else begin
        for(int i = 0; i < 16; i++) begin
            if(~address_table[i][33] && (bmem_itf_read || delayed_inst_request)) begin
                if(latch_data_bmem)begin
                   address_table[i] <= {1'b1, 1'b1, data_bmem_addr};
                end
                else if(inst_request || (delayed_inst_request && ~is_writing)) begin
                    address_table[i] <= {1'b1, 1'b0, instr_bmem_addr};
                end
                else if(data_request)
                    address_table[i] <= {1'b1, 1'b1, data_bmem_addr};
                break;
            end
        end
        for(int i = 0; i < 16; i++) begin
            if(address_table[i][33] && address_table[i][31:0] == bmem_itf_raddr && read_counter == 3'h3 && bmem_itf_rvalid) begin
                address_table[i][33] <= 1'b0;
                break;
            end
        end
    end
end

always_comb begin
    // Select out dmem_resp to drive data cache
    if(is_writing)
        dmem_resp_from_bmem = (write_counter == 3'h3);
    else
        dmem_resp_from_bmem = data_bmem_rvalid;
end

// Send out data to correct cache once we receive it back
always_comb begin
    for(int i = 0; i < 16; i++) begin
        if(address_table[i][33] && address_table[i][31:0] == bmem_itf_raddr
           && read_counter == 3'h3) begin
                // Goes to data cache
                if(address_table[i][32]) begin
                    data_bmem_rdata = {bmem_itf_rdata, read_dword_buffer[2], read_dword_buffer[1], read_dword_buffer[0]};
                    data_bmem_rvalid = 1'b1;
                    instr_bmem_rdata = 'x;
                    instr_bmem_rvalid = 1'b0;
                end
                // Goes to instruction cache
                else begin
                    data_bmem_rdata = 'x;
                    data_bmem_rvalid = 1'b0;
                    instr_bmem_rdata = {bmem_itf_rdata, read_dword_buffer[2], read_dword_buffer[1], read_dword_buffer[0]};
                    instr_bmem_rvalid = 1'b1;
                end
                break;
           end
        else begin
            data_bmem_rdata = 'x;
            data_bmem_rvalid = 1'b0;
            instr_bmem_rdata = 'x;
            instr_bmem_rvalid = 1'b0;
        end
    end
end

// Send out request to bmem
always_comb begin
    // Data on the previous cycle that wasn't serviced
    if(latch_data_bmem && bmem_itf_ready) begin
        bmem_itf_addr = data_bmem_addr_reg;
        // reading & writing data
        if(data_bmem_read_reg) begin
            bmem_itf_wdata = 'x;
            bmem_itf_read = data_bmem_read_reg;
            bmem_itf_write = '0;
        end
        else if(data_bmem_write_reg || is_writing) begin
            if(is_writing)
                bmem_itf_wdata = write_dword_buffer[write_counter - 1'b1]; // Need to actually set write data
            else
                bmem_itf_wdata = data_bmem_wdata[63:0]; // Immediately send out lowest double word
            bmem_itf_read = '0;
            bmem_itf_write = 1'b1;
        end
        // Should never hit this
        else begin
            bmem_itf_wdata = 'x;
            bmem_itf_read = 'x;
            bmem_itf_write = 'x;
        end
    end
    // Otherwise always service instruction request first
    // Cannot interrupt a write
    else if(((inst_request || delayed_inst_request) && ~is_writing) && bmem_itf_ready) begin
        bmem_itf_wdata = 'x;
        bmem_itf_addr = instr_bmem_addr;
        bmem_itf_read = 1'b1;
        bmem_itf_write = '0;
    end
    // Otherwise service data request
    else if((data_request || is_writing) && bmem_itf_ready) begin
        if(is_writing)
            bmem_itf_addr = dmem_writeback_addr;
        else
            bmem_itf_addr = data_bmem_addr;
        // reading & writing data
        if(data_bmem_read) begin
            bmem_itf_wdata = 'x;
            bmem_itf_read = data_bmem_read;
            bmem_itf_write = '0;
        end
        else if(data_bmem_write || is_writing) begin
            if(is_writing)
                bmem_itf_wdata = write_dword_buffer[write_counter - 1'b1]; // Need to actually set write data
            else
                bmem_itf_wdata = data_bmem_wdata[63:0]; // Immediately send out lowest double word
            bmem_itf_read = '0;
            bmem_itf_write = 1'b1;
        end
        // Should never hit this
        else begin
            bmem_itf_wdata = 'x;
            bmem_itf_read = 'x;
            bmem_itf_write = 'x;
        end
    end
    // When we have nothing to do
    else begin
        bmem_itf_wdata = 'x;
        bmem_itf_addr = 'x;
        bmem_itf_read = '0;
        bmem_itf_write = '0;
    end

end

endmodule : cache_arbiter
