`timescale 1ns/1ps

// SPI master, mode 0 (CPOL=0, CPHA=0), 8 bits per transfer, MSB first.
// SCLK toggles every (div+1) clocks, so f_sclk = f_clk / (2*(div+1)).
// Pulse `start` for one clock while `busy` is low.
module spi_master (
    input  logic        clk,
    input  logic        rst,
    input  logic        start,
    input  logic [7:0]  tx_data,
    input  logic [15:0] div,
    output logic        busy,
    output logic [7:0]  rx_data,
    output logic        sclk,
    output logic        mosi,
    input  logic        miso
);

    logic [15:0] cnt;
    logic [2:0]  bitcnt;
    logic [7:0]  tx_sh, rx_sh;

    always_ff @(posedge clk) begin
        if (rst) begin
            busy    <= 1'b0;
            sclk    <= 1'b0;
            mosi    <= 1'b0;
            cnt     <= 16'd0;
            bitcnt  <= 3'd0;
            tx_sh   <= 8'd0;
            rx_sh   <= 8'd0;
            rx_data <= 8'd0;
        end else if (!busy) begin
            if (start) begin
                busy   <= 1'b1;
                tx_sh  <= tx_data;
                mosi   <= tx_data[7];            // first bit is ready before the first rising edge
                bitcnt <= 3'd0;
                cnt    <= div;
                sclk   <= 1'b0;
            end
        end else begin
            if (cnt == 16'd0) begin
                cnt  <= div;
                sclk <= ~sclk;
                if (!sclk) begin                 // rising edge: sample MISO
                    rx_sh <= {rx_sh[6:0], miso};
                end else begin                   // falling edge: next bit out, or finish
                    if (bitcnt == 3'd7) begin
                        busy    <= 1'b0;
                        rx_data <= rx_sh;        // all 8 bits were sampled on rising edges
                    end else begin
                        bitcnt <= bitcnt + 3'd1;
                        tx_sh  <= {tx_sh[6:0], 1'b0};
                        mosi   <= tx_sh[6];
                    end
                end
            end else begin
                cnt <= cnt - 16'd1;
            end
        end
    end

endmodule
