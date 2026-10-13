`timescale 1ns/1ps

// UART transmitter, 8N1 (1 start bit, 8 data bits LSB first, no parity, 1 stop bit).
// Pulse `start` for one clock with `data` valid while `busy` is low.
module uart_tx #(
    parameter int CLK_HZ = 50_000_000,
    parameter int BAUD   = 115_200
) (
    input  logic       clk,
    input  logic       rst,
    input  logic       start,
    input  logic [7:0] data,
    output logic       busy,
    output logic       tx
);

    localparam int DIV = CLK_HZ / BAUD;          // clock cycles per bit
    localparam int CW  = (DIV > 1) ? $clog2(DIV) : 1;

    logic [9:0]    shreg;                        // {stop, data[7:0], start}
    logic [CW-1:0] cnt;                          // counts clocks within one bit
    logic [3:0]    bits;                         // bits left to send (0 = idle)

    assign busy = (bits != 4'd0);

    always_ff @(posedge clk) begin
        if (rst) begin
            tx    <= 1'b1;
            bits  <= 4'd0;
            cnt   <= '0;
            shreg <= 10'h3FF;
        end else if (!busy) begin
            tx <= 1'b1;
            if (start) begin
                shreg <= {1'b1, data, 1'b0};
                tx    <= 1'b0;                   // start bit goes out immediately
                bits  <= 4'd10;
                cnt   <= CW'(DIV - 1);
            end
        end else begin
            if (cnt == '0) begin
                cnt  <= CW'(DIV - 1);
                bits <= bits - 4'd1;
                if (bits != 4'd1) begin          // more bits to send
                    shreg <= {1'b1, shreg[9:1]};
                    tx    <= shreg[1];
                end                              // else: frame finished, tx stays high
            end else begin
                cnt <= cnt - 1'b1;
            end
        end
    end

endmodule
