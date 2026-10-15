`timescale 1ns/1ps

// Memory-mapped SPI master.  Register offsets (word access):
//   0x00  DATA    write: start a transfer of the low 8 bits (ignored while busy)
//                 read : byte received during the last transfer
//   0x04  STATUS  bit0 = busy
//   0x08  CTRL    bit0 = CS_N output level (1 = slave deselected, reset value)
//   0x0C  CLKDIV  SCLK = CLK / (2*(CLKDIV+1))   (use CLKDIV >= 3)
module spi #(
    parameter int DEFAULT_DIV = 24                 // 1 MHz SCLK from a 50 MHz clock
) (
    input  logic        clk,
    input  logic        rst,
    input  logic        we,
    input  logic [31:0] addr,
    input  logic [31:0] wdata,
    output logic [31:0] rdata,
    output logic        sclk,
    output logic        mosi,
    input  logic        miso,
    output logic        cs_n
);

    logic        busy, start;
    logic [7:0]  rx_data;
    logic [15:0] div_reg = 16'(DEFAULT_DIV);
    logic        cs_reg  = 1'b1;
    logic        miso_s1 = 1'b0, miso_s2 = 1'b0;      // 2-FF synchroniser

    assign start = we && (addr[3:2] == 2'd0) && !busy;
    assign cs_n  = cs_reg;

    always_ff @(posedge clk) begin
        miso_s1 <= miso;
        miso_s2 <= miso_s1;
        if (rst) begin
            cs_reg  <= 1'b1;
            div_reg <= 16'(DEFAULT_DIV);
        end else if (we) begin
            if (addr[3:2] == 2'd2) cs_reg  <= wdata[0];
            if (addr[3:2] == 2'd3) div_reg <= wdata[15:0];
        end
    end

    spi_master u_master (
        .clk(clk), .rst(rst), .start(start), .tx_data(wdata[7:0]), .div(div_reg),
        .busy(busy), .rx_data(rx_data), .sclk(sclk), .mosi(mosi), .miso(miso_s2)
    );

    always_comb begin
        case (addr[3:2])
            2'd0:    rdata = {24'd0, rx_data};
            2'd1:    rdata = {31'd0, busy};
            2'd2:    rdata = {31'd0, cs_reg};
            default: rdata = {16'd0, div_reg};
        endcase
    end

endmodule
