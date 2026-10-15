`timescale 1ns/1ps

// UART receiver, 8N1.  `valid` pulses for one clock when a byte has been received.
module uart_rx #(
    parameter int CLK_HZ = 50_000_000,
    parameter int BAUD   = 115_200
) (
    input  logic       clk,
    input  logic       rst,
    input  logic       rx,
    output logic [7:0] data,
    output logic       valid,
    output logic       frame_err
);

    localparam int DIV  = CLK_HZ / BAUD;                 // clock cycles per bit
    localparam int HALF = (DIV / 2 > 0) ? DIV / 2 : 1;   // to reach the middle of a bit
    localparam int CW   = (DIV > 1) ? $clog2(DIV) : 1;

    typedef enum logic [1:0] {IDLE, START, DATA, STOP} state_t;

    state_t        state;
    logic          rx_s1 = 1'b1, rx_s2 = 1'b1;           // 2-FF synchroniser
    logic [CW-1:0] cnt;
    logic [2:0]    bitidx;
    logic [7:0]    shreg;

    always_ff @(posedge clk) begin
        rx_s1 <= rx;
        rx_s2 <= rx_s1;
        valid <= 1'b0;

        if (rst) begin
            state     <= IDLE;
            cnt       <= '0;
            bitidx    <= 3'd0;
            shreg     <= 8'd0;
            data      <= 8'd0;
            frame_err <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (!rx_s2) begin                    // falling edge: start bit?
                        state <= START;
                        cnt   <= CW'(HALF - 1);
                    end
                end
                START: begin                             // wait to the middle of the start bit
                    if (cnt == '0) begin
                        if (!rx_s2) begin                // still low: real start bit
                            state  <= DATA;
                            cnt    <= CW'(DIV - 1);
                            bitidx <= 3'd0;
                        end else begin
                            state <= IDLE;               // glitch, ignore
                        end
                    end else cnt <= cnt - 1'b1;
                end
                DATA: begin                              // sample each bit in its middle
                    if (cnt == '0) begin
                        shreg <= {rx_s2, shreg[7:1]};    // LSB first
                        cnt   <= CW'(DIV - 1);
                        if (bitidx == 3'd7) state <= STOP;
                        else                bitidx <= bitidx + 3'd1;
                    end else cnt <= cnt - 1'b1;
                end
                STOP: begin
                    if (cnt == '0) begin
                        data      <= shreg;
                        valid     <= 1'b1;
                        frame_err <= ~rx_s2;             // stop bit must be 1
                        state     <= IDLE;
                    end else cnt <= cnt - 1'b1;
                end
                default: state <= IDLE;
            endcase
        end
    end

endmodule
