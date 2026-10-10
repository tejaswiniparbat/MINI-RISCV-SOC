`timescale 1ns/1ps

module gpio_tb;

    logic        clk = 1'b0, rst = 1'b1, we = 1'b0;
    logic [31:0] addr = '0, wdata = '0, rdata;
    logic [15:0] pins_in = '0, pins_out;
    int errors = 0, tests = 0;

    gpio #(.W(16)) dut (.clk(clk), .rst(rst), .we(we), .addr(addr), .wdata(wdata),
                        .rdata(rdata), .pins_in(pins_in), .pins_out(pins_out));

    always #5 clk = ~clk;

    task automatic write(input logic [31:0] a, input logic [31:0] d);
        @(negedge clk); we = 1'b1; addr = a; wdata = d;
        @(negedge clk); we = 1'b0;
    endtask

    task automatic check(input string name, input logic [31:0] got, input logic [31:0] exp);
        tests++;
        if (got !== exp) begin errors++; $display("FAIL %-18s got=%h expected=%h", name, got, exp); end
        else $display("PASS %-18s = %h", name, got);
    endtask

    initial begin
        repeat (2) @(posedge clk);
        @(negedge clk) rst = 1'b0;

        check("reset: pins_out", 32'(pins_out), 32'h0000);
        write(32'h1000_0000, 32'hFFFF_A5A5);
        check("write OUT", 32'(pins_out), 32'hA5A5);
        addr = 32'h1000_0000; #1;
        check("read back OUT", rdata, 32'h0000A5A5);

        write(32'h1000_0004, 32'h0000_FFFF);          // IN is read-only
        check("write IN ignored", 32'(pins_out), 32'hA5A5);

        pins_in = 16'h1234;
        repeat (3) @(posedge clk);                     // 2-FF synchroniser
        addr = 32'h1000_0004; #1;
        check("read IN", rdata, 32'h00001234);

        addr = 32'h1000_0008; #1;
        check("unused reg = 0", rdata, 32'h0);

        rst = 1'b1; @(posedge clk); #1;
        check("reset clears OUT", 32'(pins_out), 32'h0000);

        if (errors == 0) $display("ALL %0d TESTS PASSED", tests);
        else             $display("%0d of %0d TESTS FAILED", errors, tests);
        $finish;
    end

endmodule
