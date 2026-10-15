`timescale 1ns/1ps

// Memory-mapped UART.  Register offsets (word access):
//   0x00  TXDATA  (write)  low 8 bits are sent; ignored while busy
//   0x04  STATUS  (read)   bit0 = TX ready, bit1 = RX byte available, bit2 = RX overrun
//   0x08  RXDATA  (read)   received byte; reading it clears bits 1 and 2 of STATUS
module uart #(
    parameter int CLK_HZ = 50_000_000,
    parameter int BAUD   = 115_200
) (
    input  logic        clk,
    input  logic        rst,
    input  logic        we,
    input  logic        re,
    input  logic [31:0] addr,
    input  logic [31:0] wdata,
    output logic [31:0] rdata,
    output logic        tx,
    input  logic        rx
);

    // ---------------- transmit ----------------
    logic busy, start;

    assign start = we && (addr[3:2] == 2'd0) && !busy;

    uart_tx #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) u_tx (
        .clk(clk), .rst(rst), .start(start), .data(wdata[7:0]), .busy(busy), .tx(tx)
    );

    // ---------------- receive ----------------
    logic [7:0] rx_byte, rx_data = 8'd0;
    logic       rx_pulse, rx_valid = 1'b0, rx_over = 1'b0;
    logic       rx_pop;

    assign rx_pop = re && (addr[3:2] == 2'd2);

    uart_rx #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) u_rx (
        .clk(clk), .rst(rst), .rx(rx), .data(rx_byte), .valid(rx_pulse), .frame_err()
    );

    always_ff @(posedge clk) begin
        if (rst) begin
            rx_valid <= 1'b0;
            rx_over  <= 1'b0;
        end else begin
            if (rx_pop) begin                    // software read the byte
                rx_valid <= 1'b0;
                rx_over  <= 1'b0;
            end
            if (rx_pulse) begin                  // new byte arrived (wins over a same-cycle pop)
                if (rx_valid && !rx_pop) rx_over <= 1'b1;
                rx_data  <= rx_byte;
                rx_valid <= 1'b1;
            end
        end
    end

    always_comb begin
        case (addr[3:2])
            2'd1:    rdata = {29'd0, rx_over, rx_valid, ~busy};
            2'd2:    rdata = {24'd0, rx_data};
            default: rdata = 32'd0;
        endcase
    end

endmodule
