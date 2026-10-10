`timescale 1ns/1ps

// SoC top level: core + peripherals.  This is what goes on the FPGA.
// Peripheral address map (core sends 0x1xxx_xxxx here):
//   0x1000_0000 - 0x1000_00FF   GPIO
module soc_top #(
    parameter string INIT_FILE = "firmware/gpio_demo.hex"
) (
    input  logic        clk,
    input  logic        rst,
    input  logic [15:0] gpio_in,
    output logic [15:0] gpio_out
);

    logic        io_we;
    logic [31:0] io_addr, io_wdata, io_rdata;
    logic [31:0] gpio_rdata;
    logic [31:0] pc_unused;
    logic        gpio_sel;

    core #(.INIT_FILE(INIT_FILE)) u_core (
        .clk(clk), .rst(rst), .pc_out(pc_unused),
        .io_we(io_we), .io_addr(io_addr), .io_wdata(io_wdata), .io_rdata(io_rdata)
    );

    assign gpio_sel = (io_addr[15:8] == 8'h00);

    gpio #(.W(16)) u_gpio (
        .clk(clk), .rst(rst),
        .we(io_we & gpio_sel), .addr(io_addr), .wdata(io_wdata), .rdata(gpio_rdata),
        .pins_in(gpio_in), .pins_out(gpio_out)
    );

    assign io_rdata = gpio_sel ? gpio_rdata : 32'd0;

endmodule
