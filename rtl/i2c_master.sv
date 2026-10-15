`timescale 1ns/1ps

// I2C master, byte-level command interface.
// One command = [START] + [WRITE byte | READ byte] + [STOP], each part optional.
//   cmd[0] START   cmd[1] STOP   cmd[2] WRITE   cmd[3] READ   cmd[4] NACK (answer to a READ: 1 = NACK)
// Every bit takes 4 ticks, a tick is (div+1) clocks, so f_scl = f_clk / (4*(div+1)).
// scl_o / sda_o are open-drain levels: 0 = pull the line low, 1 = release it.
module i2c_master (
    input  logic        clk,
    input  logic        rst,
    input  logic        cmd_valid,
    input  logic [4:0]  cmd,
    input  logic [7:0]  tx_data,
    input  logic [15:0] div,
    output logic        busy,
    output logic        nack,          // last WRITE was not acknowledged
    output logic [7:0]  rx_data,
    output logic        scl_o,
    output logic        sda_o,
    input  logic        sda_i
);

    typedef enum logic [1:0] {IDLE, START, BYTE, STOP} state_t;

    state_t      state;
    logic [1:0]  phase;                      // 4 phases per bit
    logic [3:0]  bitidx;                     // 0..7 data bits, 8 = ACK bit
    logic [15:0] cnt;
    logic [7:0]  shreg;
    logic        c_start, c_stop, c_wr, c_rd, c_ack_out;
    logic        scl_c, sda_c;
    logic        scl_h = 1'b1, sda_h = 1'b1; // line levels held between commands
    logic        sda_s1 = 1'b1, sda_s2 = 1'b1;

    // ---------------- line levels for the current state/phase ----------------
    always_comb begin
        scl_c = scl_h;
        sda_c = sda_h;
        case (state)
            START: begin                      // ph0: SCL=0 SDA=1, ph1: 1/1, ph2: 1/0 (the START), ph3: 0/0
                scl_c = (phase == 2'd1) || (phase == 2'd2);
                sda_c = (phase == 2'd0) || (phase == 2'd1);
            end
            BYTE: begin
                scl_c = (phase == 2'd1) || (phase == 2'd2);
                if (c_wr) sda_c = (bitidx < 4'd8) ? shreg[7] : 1'b1;   // release for the ACK bit
                else      sda_c = (bitidx < 4'd8) ? 1'b1 : c_ack_out;  // release while reading
            end
            STOP: begin                       // ph0: 0/0, ph1: 1/0, ph2: 1/1 (the STOP), ph3: 1/1
                scl_c = (phase != 2'd0);
                sda_c = (phase >= 2'd2);
            end
            default: ;
        endcase
    end

    assign scl_o = scl_c;
    assign sda_o = sda_c;

    // ---------------- control ----------------
    always_ff @(posedge clk) begin
        sda_s1 <= sda_i;
        sda_s2 <= sda_s1;

        if (rst) begin
            state      <= IDLE;
            phase      <= 2'd0;
            bitidx     <= 4'd0;
            cnt        <= 16'd0;
            shreg      <= 8'd0;
            busy       <= 1'b0;
            nack       <= 1'b0;
            rx_data    <= 8'd0;
            c_start    <= 1'b0;
            c_stop     <= 1'b0;
            c_wr       <= 1'b0;
            c_rd       <= 1'b0;
            c_ack_out  <= 1'b0;
            scl_h      <= 1'b1;
            sda_h      <= 1'b1;
        end else begin
            if (state != IDLE) begin
                scl_h <= scl_c;
                sda_h <= sda_c;
            end

            if (state == IDLE) begin
                if (cmd_valid && (cmd[3:0] != 4'd0)) begin
                    c_start   <= cmd[0];
                    c_stop    <= cmd[1];
                    c_wr      <= cmd[2];
                    c_rd      <= cmd[3] & ~cmd[2];
                    c_ack_out <= cmd[4];
                    shreg     <= tx_data;
                    busy      <= 1'b1;
                    phase     <= 2'd0;
                    bitidx    <= 4'd0;
                    cnt       <= div;
                    if (cmd[0])                state <= START;
                    else if (cmd[2] | cmd[3])  state <= BYTE;
                    else                       state <= STOP;
                end
            end else begin
                if (cnt == 16'd0) begin
                    cnt <= div;
                    case (state)
                        START: begin
                            if (phase == 2'd3) begin
                                phase <= 2'd0;
                                if (c_wr | c_rd)  state <= BYTE;
                                else if (c_stop)  state <= STOP;
                                else begin state <= IDLE; busy <= 1'b0; end
                            end else phase <= phase + 2'd1;
                        end
                        BYTE: begin
                            if (phase == 2'd2) begin                       // SCL high: sample SDA
                                if (c_wr) begin
                                    if (bitidx == 4'd8) nack <= sda_s2;    // slave pulls low = ACK
                                end else if (bitidx < 4'd8) begin
                                    shreg <= {shreg[6:0], sda_s2};
                                end
                            end
                            if (phase == 2'd3) begin
                                phase <= 2'd0;
                                if (c_wr && bitidx < 4'd8) shreg <= {shreg[6:0], 1'b0};
                                if (bitidx == 4'd8) begin                  // byte finished
                                    if (c_rd) rx_data <= shreg;
                                    if (c_stop) state <= STOP;
                                    else begin state <= IDLE; busy <= 1'b0; end
                                end else bitidx <= bitidx + 4'd1;
                            end else phase <= phase + 2'd1;
                        end
                        STOP: begin
                            if (phase == 2'd3) begin
                                phase <= 2'd0;
                                state <= IDLE;
                                busy  <= 1'b0;
                            end else phase <= phase + 2'd1;
                        end
                        default: state <= IDLE;
                    endcase
                end else begin
                    cnt <= cnt - 16'd1;
                end
            end
        end
    end

endmodule
