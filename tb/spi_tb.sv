`timescale 1ns/1ps

// Tests the memory-mapped SPI master against a behavioural mode-0 SPI slave.
// Slave replies A5, 5A, C3 and records what it receives.
module spi_tb;

    logic        clk = 1'b0, rst = 1'b1, we = 1'b0;
    logic [31:0] addr = '0, wdata = '0, rdata;
    logic        sclk, mosi, cs_n;
    logic        miso = 1'b0;
    int errors = 0, tests = 0;

    spi #(.DEFAULT_DIV(24)) dut (
        .clk(clk), .rst(rst), .we(we), .addr(addr), .wdata(wdata), .rdata(rdata),
        .sclk(sclk), .mosi(mosi), .miso(miso), .cs_n(cs_n)
    );

    always #5 clk = ~clk;

    // ---------------- SPI slave model (mode 0) ----------------
    logic [7:0] resp [0:3];
    logic [7:0] got  [0:3];
    logic [7:0] sh_in = 8'd0, sh_out = 8'd0;
    int bitn = 0, byte_idx = 0, nclk = 0;

    initial begin
        resp[0] = 8'hA5; resp[1] = 8'h5A; resp[2] = 8'hC3; resp[3] = 8'h00;
        got[0] = 8'h00; got[1] = 8'h00; got[2] = 8'h00; got[3] = 8'h00;
    end

    always @(negedge cs_n) begin                 // selected: present the first bit
        byte_idx = 0; bitn = 0;
        sh_out = resp[0];
        miso   = sh_out[7];
    end

    always @(posedge sclk) if (!cs_n) begin      // rising edge: sample MOSI
        sh_in = {sh_in[6:0], mosi};
        bitn++; nclk++;
        if (bitn == 8) begin
            got[byte_idx] = sh_in;
            byte_idx++;
            bitn = 0;
        end
    end

    always @(negedge sclk) if (!cs_n) begin      // falling edge: next MISO bit
        if (bitn == 0) sh_out = resp[byte_idx];
        else           sh_out = {sh_out[6:0], 1'b0};
        miso = sh_out[7];
    end

    // ---------------- helpers ----------------
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

    task automatic check(input string name, input logic [31:0] got_v, input logic [31:0] exp);
        tests++;
        if (got_v !== exp) begin errors++; $display("FAIL %-22s got=%h expected=%h", name, got_v, exp); end
        else $display("PASS %-22s = %h", name, got_v);
    endtask

    initial begin
        repeat (3) @(posedge clk);
        @(negedge clk) rst = 1'b0;

        addr = 32'h8; #1;  check("CS_N reset value", rdata, 32'd1);
        addr = 32'hC; #1;  check("CLKDIV reset value", rdata, 32'd24);
        addr = 32'h4; #1;  check("idle after reset", rdata, 32'd0);

        write(32'hC, 32'd4);
        addr = 32'hC; #1;  check("CLKDIV written", rdata, 32'd4);

        write(32'h8, 32'd0);
        check("CS_N pin goes low", 32'(cs_n), 32'd0);

        write(32'h0, 32'h12);
        addr = 32'h4; #1;  check("busy right after write", rdata, 32'd1);
        wait_idle();
        check("8 SCLK pulses", 32'(nclk), 32'd8);
        check("SCLK idles low", 32'(sclk), 32'd0);
        addr = 32'h0; #1;  check("RX byte (A5)", rdata, 32'hA5);

        write(32'h0, 32'h34);  wait_idle();
        addr = 32'h0; #1;  check("RX byte (5A)", rdata, 32'h5A);

        write(32'h0, 32'h56);  wait_idle();
        addr = 32'h0; #1;  check("RX byte (C3)", rdata, 32'hC3);

        check("slave got 0x12", 32'(got[0]), 32'h12);
        check("slave got 0x34", 32'(got[1]), 32'h34);
        check("slave got 0x56", 32'(got[2]), 32'h56);
        check("24 SCLK pulses total", 32'(nclk), 32'd24);

        write(32'h8, 32'd1);
        check("CS_N pin goes high", 32'(cs_n), 32'd1);

        if (errors == 0) $display("ALL %0d TESTS PASSED", tests);
        else             $display("%0d of %0d TESTS FAILED", errors, tests);
        $finish;
    end

endmodule
