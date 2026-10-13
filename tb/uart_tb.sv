`timescale 1ns/1ps

// Tests the memory-mapped UART with a small baud divider (10 clocks per bit).
module uart_tb;

    localparam int DIV    = 10;
    localparam int BIT_NS = DIV * 10;          // 10 ns clock

    logic        clk = 1'b0, rst = 1'b1, we = 1'b0;
    logic [31:0] addr = '0, wdata = '0, rdata;
    logic        tx;
    int errors = 0, tests = 0;

    uart #(.CLK_HZ(1000), .BAUD(100)) dut (
        .clk(clk), .rst(rst), .we(we), .addr(addr), .wdata(wdata), .rdata(rdata), .tx(tx)
    );

    always #5 clk = ~clk;

    task automatic write(input logic [31:0] a, input logic [31:0] d);
        @(negedge clk); we = 1'b1; addr = a; wdata = d;
        @(negedge clk); we = 1'b0;
    endtask

    // Serial receiver model: waits for a start bit, samples mid-bit
    task automatic recv(output logic [7:0] b, output logic stop_ok);
        @(negedge tx);
        #(BIT_NS + BIT_NS / 2);                // middle of data bit 0
        for (int i = 0; i < 8; i++) begin
            b[i] = tx;
            #(BIT_NS);
        end
        stop_ok = tx;                          // middle of the stop bit
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
        if (got !== exp) begin errors++; $display("FAIL %-22s got=%h expected=%h", name, got, exp); end
        else $display("PASS %-22s = %h", name, got);
    endtask

    logic [7:0] rb;
    logic       sok;

    initial begin
        repeat (3) @(posedge clk);
        @(negedge clk) rst = 1'b0;

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

        // status while busy, and write-while-busy is ignored
        write(32'h0000_0000, 32'h41);                // 'A'
        addr = 32'h0000_0004; #1;
        check("busy right after write", rdata, 32'd0);
        write(32'h0000_0000, 32'h42);                // 'B' must be dropped
        repeat (12 * DIV) @(posedge clk);            // let the frame finish
        wait_ready();                                // also points addr at STATUS
        check("ready again", rdata, 32'd1);
        check("idle high again", 32'(tx), 32'd1);

        if (errors == 0) $display("ALL %0d TESTS PASSED", tests);
        else             $display("%0d of %0d TESTS FAILED", errors, tests);
        $finish;
    end

endmodule
