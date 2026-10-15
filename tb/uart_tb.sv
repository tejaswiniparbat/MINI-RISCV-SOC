`timescale 1ns/1ps

// Tests the memory-mapped UART (TX and RX) with a small baud divider (10 clocks per bit).
module uart_tb;

    localparam int DIV    = 10;
    localparam int BIT_NS = DIV * 10;          // 10 ns clock

    logic        clk = 1'b0, rst = 1'b1, we = 1'b0, re = 1'b0;
    logic [31:0] addr = '0, wdata = '0, rdata;
    logic        tx, rx = 1'b1;
    int errors = 0, tests = 0;

    uart #(.CLK_HZ(1000), .BAUD(100)) dut (
        .clk(clk), .rst(rst), .we(we), .re(re), .addr(addr), .wdata(wdata),
        .rdata(rdata), .tx(tx), .rx(rx)
    );

    always #5 clk = ~clk;

    task automatic write(input logic [31:0] a, input logic [31:0] d);
        @(negedge clk); we = 1'b1; addr = a; wdata = d;
        @(negedge clk); we = 1'b0;
    endtask

    // read a register; with `re` high a read of RXDATA pops the byte
    task automatic read_reg(input logic [31:0] a, output logic [31:0] d);
        @(negedge clk); addr = a; re = 1'b1; #1;
        d = rdata;
        @(negedge clk); re = 1'b0;
    endtask

    // Serial receiver model for the TX pin: waits for a start bit, samples mid-bit
    task automatic recv(output logic [7:0] b, output logic stop_ok);
        @(negedge tx);
        #(BIT_NS + BIT_NS / 2);                // middle of data bit 0
        for (int i = 0; i < 8; i++) begin
            b[i] = tx;
            #(BIT_NS);
        end
        stop_ok = tx;                          // middle of the stop bit
    endtask

    // Serial transmitter model that drives the RX pin
    task automatic send_serial(input logic [7:0] b);
        rx = 1'b0; #(BIT_NS);
        for (int i = 0; i < 8; i++) begin
            rx = b[i]; #(BIT_NS);
        end
        rx = 1'b1; #(BIT_NS);
    endtask

    // like firmware: poll STATUS until the transmitter is ready
    task automatic wait_ready();
        addr = 32'h0000_0004; #1;
        while (rdata[0] == 1'b0) begin
            @(posedge clk); #1;
        end
    endtask

    task automatic check(input string name, input logic [31:0] got, input logic [31:0] exp);
        tests++;
        if (got !== exp) begin errors++; $display("FAIL %-24s got=%h expected=%h", name, got, exp); end
        else $display("PASS %-24s = %h", name, got);
    endtask

    logic [7:0]  rb;
    logic        sok;
    logic [31:0] v;

    initial begin
        repeat (3) @(posedge clk);
        @(negedge clk) rst = 1'b0;

        // ---------- transmit ----------
        addr = 32'h0000_0004; #1;
        check("ready after reset", rdata, 32'd1);
        check("line idles high", 32'(tx), 32'd1);

        fork
            write(32'h0000_0000, 32'h55);
            recv(rb, sok);
        join
        check("sent 0x55", 32'(rb), 32'h55);
        check("stop bit 0x55", 32'(sok), 32'd1);
        wait_ready();

        fork
            write(32'h0000_0000, 32'hFFFF_FFA3);     // only low 8 bits are used
            recv(rb, sok);
        join
        check("sent 0xA3", 32'(rb), 32'hA3);
        check("stop bit 0xA3", 32'(sok), 32'd1);
        wait_ready();

        write(32'h0000_0000, 32'h41);                // 'A'
        addr = 32'h0000_0004; #1;
        check("busy right after write", rdata, 32'd0);
        write(32'h0000_0000, 32'h42);                // 'B' must be dropped
        repeat (12 * DIV) @(posedge clk);            // let the frame finish
        wait_ready();
        check("ready again", rdata, 32'd1);
        check("idle high again", 32'(tx), 32'd1);

        // ---------- receive ----------
        addr = 32'h0000_0004; #1;
        check("no RX data yet", rdata, 32'd1);       // ready=1, rx_valid=0, overrun=0

        send_serial(8'h41);
        repeat (3) @(posedge clk);
        addr = 32'h0000_0004; #1;
        check("RX available", rdata, 32'd3);         // ready=1, rx_valid=1
        read_reg(32'h0000_0008, v);
        check("RX byte 0x41", v, 32'h41);
        addr = 32'h0000_0004; #1;
        check("RX cleared by read", rdata, 32'd1);

        send_serial(8'hC3);
        repeat (3) @(posedge clk);
        read_reg(32'h0000_0008, v);
        check("RX byte 0xC3", v, 32'hC3);

        send_serial(8'h11);                          // not read ...
        send_serial(8'h22);                          // ... so this overruns it
        repeat (3) @(posedge clk);
        addr = 32'h0000_0004; #1;
        check("overrun flagged", rdata, 32'd7);      // ready=1, rx_valid=1, overrun=1
        read_reg(32'h0000_0008, v);
        check("latest byte kept 0x22", v, 32'h22);
        addr = 32'h0000_0004; #1;
        check("flags cleared", rdata, 32'd1);

        if (errors == 0) $display("ALL %0d TESTS PASSED", tests);
        else             $display("%0d of %0d TESTS FAILED", errors, tests);
        $finish;
    end

endmodule
