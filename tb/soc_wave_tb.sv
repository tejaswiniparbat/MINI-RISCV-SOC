`timescale 1ns/1ps

// Waveform-only run (not part of the test suite): uart_demo firmware on the SoC.
// Writes waves/soc_wave.vcd for GTKWave.
module soc_wave_tb;

    logic        clk = 1'b0, rst = 1'b1;
    logic [15:0] gpio_out;
    logic        uart_tx;

    soc_top #(.INIT_FILE("firmware/uart_demo.hex"), .CLK_HZ(1000), .BAUD(100)) dut (
        .clk(clk), .rst(rst), .gpio_in(16'h0000), .gpio_out(gpio_out),
        .uart_tx(uart_tx), .uart_rx(1'b1),
        .spi_sclk(), .spi_mosi(), .spi_miso(1'b0), .spi_cs_n(),
        .i2c_scl_o(), .i2c_sda_o(), .i2c_sda_i(1'b1)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("waves/soc_wave.vcd");
        $dumpvars(3, soc_wave_tb);          // depth 3: testbench, soc_top, core + peripherals
        repeat (3) @(posedge clk);
        @(negedge clk) rst = 1'b0;
        repeat (3000) @(posedge clk);
        $finish;
    end

endmodule
