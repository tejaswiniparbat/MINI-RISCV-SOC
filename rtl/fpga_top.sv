`timescale 1ns/1ps

// Board-level top: clock divider, power-on/button reset, open-drain I2C pins, and the SoC.
// Port names are what the constraints file (.xdc) maps to real FPGA pins.
module fpga_top #(
    parameter int    CLK_IN_HZ = 100_000_000,          // board oscillator
    parameter int    CLK_DIV   = 2,                    // system clock = CLK_IN_HZ / CLK_DIV (1 or an even number)
    parameter int    BAUD      = 115_200,
    parameter string INIT_FILE = "firmware/board_demo.hex"
) (
    input  logic        clk_in,
    input  logic        btn_rst,                       // push button, active high
    input  logic [15:0] sw,
    output logic [15:0] led,
    input  logic        uart_rxd,
    output logic        uart_txd,
    output logic        spi_sclk,
    output logic        spi_mosi,
    input  logic        spi_miso,
    output logic        spi_cs_n,
    inout  wire         i2c_scl,
    inout  wire         i2c_sda
);

    localparam int SYS_HZ = CLK_IN_HZ / ((CLK_DIV <= 1) ? 1 : CLK_DIV);

    // ---------------- system clock ----------------
    // The single-cycle core has a long combinational path, so it runs slower than the board clock.
    logic clk_sys;

    generate
        if (CLK_DIV <= 1) begin : g_nodiv
            assign clk_sys = clk_in;
        end else begin : g_div
            logic [15:0] dcnt  = 16'd0;
            logic        clk_q = 1'b0;
            always_ff @(posedge clk_in) begin
                if (dcnt == 16'(CLK_DIV / 2 - 1)) begin
                    dcnt  <= 16'd0;
                    clk_q <= ~clk_q;
                end else begin
                    dcnt  <= dcnt + 16'd1;
                end
            end
`ifdef VERILATOR
            assign clk_sys = clk_q;                    // simulation: plain wire
`else
            BUFG u_bufg (.I(clk_q), .O(clk_sys));      // FPGA: put it on a global clock network
`endif
        end
    endgenerate

    // ---------------- reset: power-on hold + button, synchronised ----------------
    logic [3:0] por_cnt  = 4'd0;
    logic       por_done = 1'b0;
    logic       rst_s1 = 1'b1, rst_s2 = 1'b1;
    logic       rst;

    always_ff @(posedge clk_sys) begin
        if (!por_done) begin
            por_cnt <= por_cnt + 4'd1;
            if (por_cnt == 4'hF) por_done <= 1'b1;
        end
        rst_s1 <= btn_rst | ~por_done;
        rst_s2 <= rst_s1;
    end

    assign rst = rst_s2;

    // ---------------- I2C open-drain pins ----------------
    logic i2c_scl_o, i2c_sda_o, i2c_sda_i;

    assign i2c_scl   = i2c_scl_o ? 1'bz : 1'b0;        // external (or internal) pull-up makes it high
    assign i2c_sda   = i2c_sda_o ? 1'bz : 1'b0;
    assign i2c_sda_i = i2c_sda;

    // ---------------- the SoC ----------------
    soc_top #(.INIT_FILE(INIT_FILE), .CLK_HZ(SYS_HZ), .BAUD(BAUD)) u_soc (
        .clk(clk_sys), .rst(rst),
        .gpio_in(sw), .gpio_out(led),
        .uart_tx(uart_txd), .uart_rx(uart_rxd),
        .spi_sclk(spi_sclk), .spi_mosi(spi_mosi), .spi_miso(spi_miso), .spi_cs_n(spi_cs_n),
        .i2c_scl_o(i2c_scl_o), .i2c_sda_o(i2c_sda_o), .i2c_sda_i(i2c_sda_i)
    );

endmodule
