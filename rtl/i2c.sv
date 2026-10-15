`timescale 1ns/1ps

// Memory-mapped I2C master.  Register offsets (word access):
//   0x00  DATA    write: byte for the next WRITE command   read: byte from the last READ
//   0x04  STATUS  bit0 = busy, bit1 = NACK (last WRITE was not acknowledged)
//   0x08  CMD     write starts a command (ignored while busy):
//                 bit0 START, bit1 STOP, bit2 WRITE, bit3 READ, bit4 NACK (reply after a READ)
//   0x0C  CLKDIV  SCL = CLK / (4*(CLKDIV+1))    (use CLKDIV >= 3)
module i2c #(
    parameter int DEFAULT_DIV = 124                // 100 kHz SCL from a 50 MHz clock
) (
    input  logic        clk,
    input  logic        rst,
    input  logic        we,
    input  logic [31:0] addr,
    input  logic [31:0] wdata,
    output logic [31:0] rdata,
    output logic        scl_o,                     // 0 = pull low, 1 = release
    output logic        sda_o,                     // 0 = pull low, 1 = release
    input  logic        sda_i
);

    logic        busy, nack, cmd_valid;
    logic [7:0]  rx_data;
    logic [7:0]  tx_reg  = 8'd0;
    logic [15:0] div_reg = 16'(DEFAULT_DIV);

    assign cmd_valid = we && (addr[3:2] == 2'd2) && !busy;

    always_ff @(posedge clk) begin
        if (rst) begin
            tx_reg  <= 8'd0;
            div_reg <= 16'(DEFAULT_DIV);
        end else if (we) begin
            if (addr[3:2] == 2'd0) tx_reg  <= wdata[7:0];
            if (addr[3:2] == 2'd3) div_reg <= wdata[15:0];
        end
    end

    i2c_master u_master (
        .clk(clk), .rst(rst), .cmd_valid(cmd_valid), .cmd(wdata[4:0]), .tx_data(tx_reg),
        .div(div_reg), .busy(busy), .nack(nack), .rx_data(rx_data),
        .scl_o(scl_o), .sda_o(sda_o), .sda_i(sda_i)
    );

    always_comb begin
        case (addr[3:2])
            2'd0:    rdata = {24'd0, rx_data};
            2'd1:    rdata = {30'd0, nack, busy};
            2'd2:    rdata = 32'd0;
            default: rdata = {16'd0, div_reg};
        endcase
    end

endmodule
