module top_tb;

    timeunit 1ps;
    timeprecision 1ps;

    int clock_half_period_ps = 5;

    bit clk;
    always #(clock_half_period_ps) clk = ~clk;

    bit rst;

    int timeout = 10000; // in cycles, change according to your needs

    // Explicit dual port connections when caches are not integrated into design yet (Before CP3)
    /*
    mem_itf mem_itf_i(.*);
    mem_itf mem_itf_d(.*);
    magic_dual_port mem(.itf_i(mem_itf_i), .itf_d(mem_itf_d));
    */

    // Single memory port connection when caches are integrated into design (CP3 and after)
    
    // Instruction memory
    banked_mem_itf banked_itf_i(.*);
    banked_memory banked_memory_i(.itf(banked_itf_i));

    mem_itf mem_itf_i(.*);
    
    // Instruction Cache
    cache inst_cache
    (
        .clk(clk), .rst(rst),

        .ufp_addr(mem_itf_i.addr),
        .ufp_rmask(mem_itf_i.rmask),
        .ufp_wmask('0),
        .ufp_rdata(mem_itf_i.rdata),
        .ufp_wdata(),
        .ufp_resp(mem_itf_i.resp),

        .dfp_addr(banked_itf_i.addr),
        .dfp_read(banked_itf_i.read),
        .dfp_write(banked_itf_i.write),
        .dfp_rdata(banked_itf_i.rdata),
        .dfp_wdata(banked_itf_i.wdata),
        .dfp_resp(banked_itf_i.rvalid)
    );

    // Data memory
    banked_mem_itf banked_itf_d(.*);
    banked_memory banked_memory_d(.itf(banked_itf_d));

    mem_itf mem_itf_d(.*);

    // Data Cache
    cache data_cache
    (
        .clk(clk), .rst(rst),

        .ufp_addr(mem_itf_d.addr),
        .ufp_rmask(mem_itf_d.rmask),
        .ufp_wmask(mem_itf_d.wmask),
        .ufp_rdata(mem_itf_d.rdata),
        .ufp_wdata(mem_itf_d.wdata),
        .ufp_resp(mem_itf_d.resp),

        .dfp_addr(banked_itf_d.addr),
        .dfp_read(banked_itf_d.read),
        .dfp_write(banked_itf_d.write),
        .dfp_rdata(banked_itf_d.rdata),
        .dfp_wdata(banked_itf_d.wdata),
        .dfp_resp(banked_itf_d.rvalid)
    );

    mon_itf mon_itf(.*);    
    monitor monitor(.itf(mon_itf));

    cpu #(.SS(1)) dut(
        .clk            (clk),
        .rst            (rst),

        // Explicit dual port connections when caches are not integrated into design yet (Before CP3)
        .imem_addr      (mem_itf_i.addr),
        .imem_rmask     (mem_itf_i.rmask),
        .imem_rdata     (mem_itf_i.rdata),
        .imem_resp      (mem_itf_i.resp),

        .dmem_addr      (mem_itf_d.addr),
        .dmem_rmask     (mem_itf_d.rmask),
        .dmem_wmask     (mem_itf_d.wmask),
        .dmem_rdata     (mem_itf_d.rdata),
        .dmem_wdata     (mem_itf_d.wdata),
        .dmem_resp      (mem_itf_d.resp)

        // Single memory port connection when caches are integrated into design (CP3 and after)
        /*
        .bmem_addr(bmem_itf.addr),
        .bmem_read(bmem_itf.read),
        .bmem_write(bmem_itf.write),
        .bmem_wdata(bmem_itf.wdata),
        .bmem_ready(bmem_itf.ready),
        .bmem_raddr(bmem_itf.raddr),
        .bmem_rdata(bmem_itf.rdata),
        .bmem_rvalid(bmem_itf.rvalid)
        */

    );

    `include "../../hvl/rvfi_reference.svh"

    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, "+all");
        rst = 1'b1;
        repeat (2) @(posedge clk);
        rst <= 1'b0;
    end

    always @(posedge clk) begin
        for (int unsigned i=0; i < 8; ++i) begin
            if (mon_itf.halt[i]) begin
                $finish;
            end
        end
        if (timeout == 0) begin
            $error("TB Error: Timed out");
            $finish;
        end
        if (mon_itf.error != 0) begin
            repeat (5) @(posedge clk);
            $finish;
        end
        if (mem_itf_i.error != 0) begin
            repeat (5) @(posedge clk);
            $finish;
        end
        if (mem_itf_d.error != 0) begin
            repeat (5) @(posedge clk);
            $finish;
        end
        timeout <= timeout - 1;
    end

endmodule
