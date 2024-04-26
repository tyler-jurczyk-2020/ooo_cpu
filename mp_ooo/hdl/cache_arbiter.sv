module cache_arbiter
import rv32i_types::*;
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

logic inst_request;
logic data_request;
// Mux select dfp_resp on data cache
logic dmem_resp_from_bmem;
logic [31:0] dmem_writeback_addr;
logic inst_prefetch;
logic [255:0] instr_bmem_prefetch_rdata;
logic instr_bmem_prefetch_rvalid;
logic [31:0] instr_bmem_prefetch_addr;

servicing_t service_state, next_service_state;
logic ack_instr, ack_data;

inst_cache #(.READ_SIZE(32*SS), .OFFSET(3)) inst_cache
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
    .dfp_resp(instr_bmem_rvalid),
    .prefetch(inst_prefetch),
    .ack(ack_instr),
    .prefetch_addr(instr_bmem_prefetch_addr),
    .prefetch_rdata(instr_bmem_prefetch_rdata),
    .prefetch_rvalid(instr_bmem_prefetch_rvalid)
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
    // .in_service(in_service_data), // Need to add this back
);

logic [63:0] read_dword_buffer [3], write_dword_buffer [3]; // No need to buffer fourth entry since we can forward it immediately
logic [2:0] read_counter, write_counter;
logic is_writing;
logic latch_data_bmem;
logic   [31:0]      data_bmem_addr_reg;
logic               data_bmem_read_reg;
logic               data_bmem_write_reg;
logic simultaneous_requests;

assign simultaneous_requests = inst_request && data_request;
assign inst_request = instr_bmem_read;
assign data_request = data_bmem_read || data_bmem_write;


// Next service state logic
always_comb begin
    if(inst_request && data_request)
        next_service_state = data_t;
    else if(inst_request)
        next_service_state = inst_t;
    else
        next_service_state = service_state;
    end

always_ff @(posedge clk) begin
    if(rst) begin
        service_state <= inst_t;
    end
    else begin
        service_state <= next_service_state;
    end
end

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

        if(service_state == data_t && data_bmem_write) begin
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

// Implement address table once cache can take more than one request
// MSB is valid, next MSB is 0 if instruction or 1 if data
address_entry_t address_table [16];

// Update address table entry 
always_ff @(posedge clk) begin
    if(rst)begin
        for(int i = 0; i < 16; i++)begin
            address_table[i] <= '0;
        end
    end
    else begin
        for(int i = 0; i < 16; i++) begin
            if(~address_table[i].valid && bmem_itf_read) begin
                if(service_state == inst_t) begin
                   address_table[i].valid <= 1'b1;
                   address_table[i].is_for_data_cache <= 1'b0;
                   address_table[i].prefetch <= inst_prefetch;
                   if(inst_prefetch)
                       address_table[i].addr <= instr_bmem_prefetch_addr;
                   else
                       address_table[i].addr <= instr_bmem_addr;
                end
                else if(service_state == data_t) begin
                    address_table[i].valid <= 1'b1;
                    address_table[i].is_for_data_cache <= 1'b1;
                    address_table[i].prefetch <= 1'b0;
                    address_table[i].addr <= data_bmem_addr;
                end
                break;
            end
        end
        for(int i = 0; i < 16; i++) begin
            if(address_table[i].valid && address_table[i].addr == bmem_itf_raddr && read_counter == 3'h3 && bmem_itf_rvalid) begin
                address_table[i].valid <= 1'b0;
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
    data_bmem_rdata = 'x;
    data_bmem_rvalid = 1'b0;
    instr_bmem_rdata = 'x;
    instr_bmem_rvalid = 1'b0;
    instr_bmem_prefetch_rdata = 'x;
    instr_bmem_prefetch_rvalid = 1'b0;
    for(int i = 0; i < 16; i++) begin
        if(address_table[i].valid && address_table[i].addr == bmem_itf_raddr
           && read_counter == 3'h3) begin
            // Goes to data cache
            if(address_table[i].is_for_data_cache && ~address_table[i].prefetch) begin
                data_bmem_rdata = {bmem_itf_rdata, read_dword_buffer[2], read_dword_buffer[1], read_dword_buffer[0]};
                data_bmem_rvalid = 1'b1;
            end
            // Goes to instruction cache
            else if(~address_table[i].is_for_data_cache && ~address_table[i].prefetch) begin
                instr_bmem_rdata = {bmem_itf_rdata, read_dword_buffer[2], read_dword_buffer[1], read_dword_buffer[0]};
                instr_bmem_rvalid = 1'b1;
            end
            else if(~address_table[i].is_for_data_cache && address_table[i].prefetch) begin
                instr_bmem_prefetch_rdata = {bmem_itf_rdata, read_dword_buffer[2], read_dword_buffer[1], read_dword_buffer[0]};
                instr_bmem_prefetch_rvalid = 1'b1;
            end
            break;
        end
    end
end

// Send out request to bmem
always_comb begin
    bmem_itf_wdata = 'x;
    bmem_itf_addr = 'x;
    bmem_itf_read = 1'b0;
    bmem_itf_write = 1'b0;
    ack_instr = 1'b0;
    if(service_state == inst_t && bmem_itf_ready) begin
        if(inst_prefetch) begin
            bmem_itf_addr = instr_bmem_prefetch_addr;
            bmem_itf_read = inst_prefetch;
        end
        else begin
            bmem_itf_addr = instr_bmem_addr;
            bmem_itf_read = instr_bmem_read;
        end
        ack_instr = 1'b1;
    end
    // Otherwise service data request
    else if(service_state == data_t && bmem_itf_ready) begin
        if(is_writing)
            bmem_itf_addr = dmem_writeback_addr;
        else
            bmem_itf_addr = data_bmem_addr;
        // reading & writing data
        if(data_bmem_read) begin
            bmem_itf_read = data_bmem_read;
        end
        else if(data_bmem_write || is_writing) begin
            if(is_writing)
                bmem_itf_wdata = write_dword_buffer[write_counter - 1'b1]; // Need to actually set write data
            else
                bmem_itf_wdata = data_bmem_wdata[63:0]; // Immediately send out lowest double word
            bmem_itf_write = 1'b1;
        end
    end
end

endmodule : cache_arbiter
