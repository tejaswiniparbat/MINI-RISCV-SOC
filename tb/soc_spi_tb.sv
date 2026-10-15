`timescale 1ns/1ps

// Runs firmware/spi_demo.hex on the SoC against a behavioural SPI slave.
// The firmware sends 12 34 56 and stores the replies (A5 5A C3) in RAM.
module soc_spi_tb;

    logic        clk = 1'b0;
    logic        rst = 1'b1;
    logic [15:0] gpio_out;
    logic        uart_tx;
    logic        spi_sclk, spi_mosi, spi_cs_n;
    logic        spi_miso = 1'b0;
    int errors = 0, tests = 0;

    soc_top #(.INIT_FILE("firmware/spi_demo.hex")) dut (
        .clk(clk), .rst(rst), .gpio_in(16'h0000), .gpio_out(gpio_out),
        .uart_tx(uart_tx), .uart_rx(1'b1),
        .spi_sclk(spi_sclk), .spi_mosi(spi_mosi), .spi_miso(spi_miso), .spi_cs_n(spi_cs_n)
    );

    always #5 clk = ~clk;

    // ---------------- SPI slave model (mode 0) ----------------
    logic [7:0] resp [0:3];
    logic [7:0] got  [0:3];
    logic [7:0] sh_in = 8'd0, sh_out = 8'd0;
    int bitn = 0, byte_idx = 0, nbytes = 0;

    initial begin
        resp[0] = 8'hA5; resp[1] = 8'h5A; resp[2] = 8'hC3; resp[3] = 8'h00;
        got[0] = 8'h00; got[1] = 8'h00; got[2] = 8'h00; got[3] = 8'h00;
    end

    always @(negedge spi_cs_n) begin
        byte_idx = 0; bitn = 0;
        sh_out   = resp[0];
        spi_miso = sh_out[7];
    end

    always @(posedge spi_sclk) if (!spi_cs_n) begin
        sh_in = {sh_in[6:0], spi_mosi};
        bitn++;
        if (bitn == 8) begin
            got[byte_idx] = sh_in;
            byte_idx++; nbytes++;
            bitn = 0;
        end
    end

    always @(negedge spi_sclk) if (!spi_cs_n) begin
        if (bitn == 0) sh_out = resp[byte_idx];
        else           sh_out = {sh_out[6:0], 1'b0};
        spi_miso = sh_out[7];
    end

    task automatic check(input string name, input logic [31:0] got_v, input logic [31:0] exp);
        tests++;
        if (got_v !== exp) begin errors++; $display("FAIL %-20s got=%h expected=%h", name, got_v, exp); end
        else $display("PASS %-20s = %h", name, got_v);
    endtask

    initial begin
        repeat (3) @(posedge clk);
        @(negedge clk) rst = 1'b0;
        repeat (3000) @(posedge clk);
        #1;

        check("firmware done",     dut.u_core.u_dmem.mem[515], 32'hC0DE600D);
        check("CLKDIV read-back",  dut.u_core.u_dmem.mem[516], 32'd4);
        check("MISO byte 0 (A5)",  dut.u_core.u_dmem.mem[512], 32'hA5);
        check("MISO byte 1 (5A)",  dut.u_core.u_dmem.mem[513], 32'h5A);
        check("MISO byte 2 (C3)",  dut.u_core.u_dmem.mem[514], 32'hC3);
        check("slave got 0x12",    32'(got[0]), 32'h12);
        check("slave got 0x34",    32'(got[1]), 32'h34);
        check("slave got 0x56",    32'(got[2]), 32'h56);
        check("3 bytes seen",      32'(nbytes), 32'd3);
        check("CS_N deselected",   32'(spi_cs_n), 32'd1);
        check("SCLK idle low",     32'(spi_sclk), 32'd0);

        if (errors == 0) $display("ALL %0d TESTS PASSED", tests);
        else             $display("%0d of %0d TESTS FAILED", errors, tests);
        $finish;
    end

endmodule
