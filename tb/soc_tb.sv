`timescale 1ns/1ps

// Runs firmware/gpio_demo.hex on the whole SoC and watches the GPIO pins.
module soc_tb;

    logic        clk = 1'b0;
    logic        rst = 1'b1;
    logic [15:0] gpio_in = 16'hA5A5;
    logic [15:0] gpio_out;
    logic [15:0] hist [0:15];
    int          n = 0;
    logic        rec = 1'b0;
    int errors = 0, tests = 0;

    soc_top #(.INIT_FILE("firmware/gpio_demo.hex"))
        dut (.clk(clk), .rst(rst), .gpio_in(gpio_in), .gpio_out(gpio_out));

    always #5 clk = ~clk;

    always @(gpio_out) if (rec && n < 16) begin hist[n] = gpio_out; n++; end

    task automatic check(input string name, input logic [31:0] got, input logic [31:0] exp);
        tests++;
        if (got !== exp) begin errors++; $display("FAIL %-16s got=%h expected=%h", name, got, exp); end
        else $display("PASS %-16s = %h", name, got);
    endtask

    initial begin
        repeat (3) @(posedge clk);
        @(negedge clk) rst = 1'b0;
        hist[0] = gpio_out; n = 1; rec = 1'b1;

        repeat (300) @(posedge clk);
        #1;
        check("history length", 32'(n), 32'd6);
        check("start",          32'(hist[0]), 32'h0000);
        check("walk 1",         32'(hist[1]), 32'h0001);
        check("walk 2",         32'(hist[2]), 32'h0002);
        check("walk 3",         32'(hist[3]), 32'h0004);
        check("walk 4",         32'(hist[4]), 32'h0008);
        check("switches->LEDs", 32'(hist[5]), 32'hA5A5);
        check("OUT read-back",  dut.u_core.u_dmem.mem[512], 32'h00000008);

        gpio_in = 16'h1234;                   // flip the "switches"
        repeat (50) @(posedge clk);
        #1;
        check("new switch value", 32'(gpio_out), 32'h1234);

        if (errors == 0) $display("ALL %0d TESTS PASSED", tests);
        else             $display("%0d of %0d TESTS FAILED", errors, tests);
        $finish;
    end

endmodule
