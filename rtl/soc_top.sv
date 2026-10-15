`timescale 1ns/1ps

// SoC top level: core + peripherals.  This is what goes on the FPGA.
// Peripheral address map (core sends 0x1xxx_xxxx here):
//   0x1000_0000 - 0x1000_00FF   GPIO
//   0x1000_0100 - 0x1000_01FF   UART
//   0x1000_0200 - 0x1000_02FF   SPI master
//   0x1000_0300 - 0x1000_03FF   I2C master
// I2C pins are open-drain levels: 0 = pull the line low, 1 = release it.
// On the FPGA board top level: assign scl = i2c_scl_o ? 1'bz : 1'b0;  (same for SDA) + pull-ups.
module soc_top #(
    parameter string INIT_FILE = "firmware/gpio_demo.hex",
    parameter int    CLK_HZ    = 50_000_000,     // set to your board's clock
    parameter int    BAUD      = 115_200
) (
    input  logic        clk,
    input  logic        rst,
    input  logic [15:0] gpio_in,
    output logic [15:0] gpio_out,
    output logic        uart_tx,
    input  logic        uart_rx,
    output logic        spi_sclk,
    output logic        spi_mosi,
    input  logic        spi_miso,
    output logic        spi_cs_n,
    output logic        i2c_scl_o,
    output logic        i2c_sda_o,
    input  logic        i2c_sda_i
);

    logic        io_we, io_re;
    logic [31:0] io_addr, io_wdata, io_rdata;
    logic [31:0] gpio_rdata, uart_rdata, spi_rdata, i2c_rdata;
    logic [31:0] pc_unused;
    logic        gpio_sel, uart_sel, spi_sel, i2c_sel;

    core #(.INIT_FILE(INIT_FILE)) u_core (
        .clk(clk), .rst(rst), .pc_out(pc_unused),
        .io_we(io_we), .io_re(io_re), .io_addr(io_addr), .io_wdata(io_wdata), .io_rdata(io_rdata)
    );

    assign gpio_sel = (io_addr[15:8] == 8'h00);
    assign uart_sel = (io_addr[15:8] == 8'h01);
    assign spi_sel  = (io_addr[15:8] == 8'h02);
    assign i2c_sel  = (io_addr[15:8] == 8'h03);

    gpio #(.W(16)) u_gpio (
        .clk(clk), .rst(rst),
        .we(io_we & gpio_sel), .addr(io_addr), .wdata(io_wdata), .rdata(gpio_rdata),
        .pins_in(gpio_in), .pins_out(gpio_out)
    );

    uart #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) u_uart (
        .clk(clk), .rst(rst),
        .we(io_we & uart_sel), .re(io_re & uart_sel),
        .addr(io_addr), .wdata(io_wdata), .rdata(uart_rdata),
        .tx(uart_tx), .rx(uart_rx)
    );

    spi u_spi (
        .clk(clk), .rst(rst),
        .we(io_we & spi_sel), .addr(io_addr), .wdata(io_wdata), .rdata(spi_rdata),
        .sclk(spi_sclk), .mosi(spi_mosi), .miso(spi_miso), .cs_n(spi_cs_n)
    );

    i2c u_i2c (
        .clk(clk), .rst(rst),
        .we(io_we & i2c_sel), .addr(io_addr), .wdata(io_wdata), .rdata(i2c_rdata),
        .scl_o(i2c_scl_o), .sda_o(i2c_sda_o), .sda_i(i2c_sda_i)
    );

    always_comb begin
        if      (gpio_sel) io_rdata = gpio_rdata;
        else if (uart_sel) io_rdata = uart_rdata;
        else if (spi_sel)  io_rdata = spi_rdata;
        else if (i2c_sel)  io_rdata = i2c_rdata;
        else               io_rdata = 32'd0;
    end

endmodule
