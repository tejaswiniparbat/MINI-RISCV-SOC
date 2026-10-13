`timescale 1ns/1ps

// Memory-mapped UART (transmit only for now).  Register offsets (word access):
//   0x00  TXDATA  (write)  low 8 bits are sent; ignored while busy
//   0x04  STATUS  (read)   bit 0 = TX ready (1 = may write a new byte)
module uart #(
    parameter int CLK_HZ = 50_000_000,
    parameter int BAUD   = 115_200
) (
    input  logic        clk,
    input  logic        rst,
    input  logic        we,
    input  logic [31:0] addr,
    input  logic [31:0] wdata,
    output logic [31:0] rdata,
    output logic        tx
);

    logic busy;
    logic start;

    assign start = we && (addr[3:2] == 2'd0) && !busy;

    uart_tx #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) u_tx (
        .clk(clk), .rst(rst), .start(start), .data(wdata[7:0]), .busy(busy), .tx(tx)
    );

    always_comb begin
        case (addr[3:2])
            2'd1:    rdata = {31'd0, ~busy};
            default: rdata = 32'd0;
        endcase
    end

endmodule
