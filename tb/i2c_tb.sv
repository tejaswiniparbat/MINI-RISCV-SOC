`timescale 1ns/1ps

// Tests the memory-mapped I2C master against a behavioural slave at address 0x50.
module i2c_tb;

    localparam logic [4:0] START = 5'b00001, STOP = 5'b00010, WRITE = 5'b00100,
                           READ  = 5'b01000, NACK = 5'b10000;

    logic        clk = 1'b0, rst = 1'b1, we = 1'b0;
    logic [31:0] addr = '0, wdata = '0, rdata;
    logic        scl_o, sda_o, slave_sda;
    wire         sda_bus = sda_o & slave_sda;      // open-drain wired-AND
    int errors = 0, tests = 0;

    i2c #(.DEFAULT_DIV(124)) dut (
        .clk(clk), .rst(rst), .we(we), .addr(addr), .wdata(wdata), .rdata(rdata),
        .scl_o(scl_o), .sda_o(sda_o), .sda_i(sda_bus)
    );

    i2c_slave_model #(.ADDR(7'h50)) slave (.scl(scl_o), .sda_in(sda_bus), .sda_out(slave_sda));

    always #5 clk = ~clk;

    task automatic write(input logic [31:0] a, input logic [31:0] d);
        @(negedge clk); we = 1'b1; addr = a; wdata = d;
        @(negedge clk); we = 1'b0;
    endtask

    task automatic wait_idle();
        addr = 32'h4; #1;
        while (rdata[0] == 1'b1) begin
            @(posedge clk); #1;
        end
    endtask

    task automatic put(input logic [7:0] b);          // load the byte to send
        write(32'h0, 32'(b));
    endtask

    task automatic cmd(input logic [4:0] c);          // run a command and wait for it
        write(32'h8, 32'(c));
        wait_idle();
    endtask

    task automatic check(input string name, input logic [31:0] got, input logic [31:0] exp);
        tests++;
        if (got !== exp) begin errors++; $display("FAIL %-26s got=%h expected=%h", name, got, exp); end
        else $display("PASS %-26s = %h", name, got);
    endtask

    initial begin
        repeat (3) @(posedge clk);
        @(negedge clk) rst = 1'b0;

        addr = 32'h4; #1;  check("idle after reset", rdata, 32'd0);
        addr = 32'hC; #1;  check("CLKDIV reset value", rdata, 32'd124);
        check("bus idle: SCL high", 32'(scl_o), 32'd1);
        check("bus idle: SDA high", 32'(sda_bus), 32'd1);

        write(32'hC, 32'd3);
        addr = 32'hC; #1;  check("CLKDIV written", rdata, 32'd3);

        // ---- write 5A, 6B to register 8 of device 0x50 ----
        put(8'hA0);  cmd(START | WRITE);
        addr = 32'h4; #1;  check("address ACKed", rdata, 32'd0);
        put(8'h08);  cmd(WRITE);
        put(8'h5A);  cmd(WRITE);
        put(8'h6B);  cmd(WRITE | STOP);
        addr = 32'h4; #1;  check("data ACKed", rdata, 32'd0);
        check("slave mem[8] = 5A", 32'(slave.mem[8]), 32'h5A);
        check("slave mem[9] = 6B", 32'(slave.mem[9]), 32'h6B);
        check("1 START seen", 32'(slave.n_start), 32'd1);
        check("1 STOP seen", 32'(slave.n_stop), 32'd1);
        check("bus idle after STOP: SCL", 32'(scl_o), 32'd1);
        check("bus idle after STOP: SDA", 32'(sda_bus), 32'd1);

        // ---- wrong address must be NACKed ----
        put(8'hA2);  cmd(START | WRITE);
        addr = 32'h4; #1;  check("wrong address NACKed", rdata, 32'd2);
        cmd(STOP);
        check("2 STOPs seen", 32'(slave.n_stop), 32'd2);

        // ---- read them back with a repeated START ----
        put(8'hA0);  cmd(START | WRITE);
        put(8'h08);  cmd(WRITE);
        put(8'hA1);  cmd(START | WRITE);                 // repeated START, read address
        addr = 32'h4; #1;  check("read address ACKed", rdata, 32'd0);
        cmd(READ);                                       // master ACKs: more to come
        addr = 32'h0; #1;  check("read byte 0 (5A)", rdata, 32'h5A);
        cmd(READ | NACK | STOP);                         // master NACKs: last byte
        addr = 32'h0; #1;  check("read byte 1 (6B)", rdata, 32'h6B);
        check("4 STARTs seen", 32'(slave.n_start), 32'd4);
        check("3 STOPs seen", 32'(slave.n_stop), 32'd3);
        check("bus idle at the end: SCL", 32'(scl_o), 32'd1);
        check("bus idle at the end: SDA", 32'(sda_bus), 32'd1);

        if (errors == 0) $display("ALL %0d TESTS PASSED", tests);
        else             $display("%0d of %0d TESTS FAILED", errors, tests);
        $finish;
    end

endmodule
