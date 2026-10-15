`timescale 1ns/1ps

// Behavioural I2C slave for testbenches: 7-bit address, 16-byte register file.
//   write: [addr+W] [register pointer] [data] [data] ...
//   read : [addr+W] [register pointer] [addr+R] then read bytes (pointer auto-increments)
module i2c_slave_model #(
    parameter logic [6:0] ADDR = 7'h50
) (
    input  logic scl,
    input  logic sda_in,       // bus level (wired-AND of all drivers)
    output logic sda_out       // 1 = release, 0 = pull low
);

    typedef enum logic [2:0] {IDLE, ADDRX, ACK_A, WRDATA, ACK_W, RDDATA, WAIT_ACK} st_t;

    st_t        st = IDLE;
    logic [7:0] mem [0:15];
    logic [7:0] sh = 8'd0;
    int         bcnt = 0, sent = 0;
    logic       rw = 1'b0, first = 1'b0, ack_m = 1'b0;
    logic [3:0] ptr = 4'd0;
    int         n_start = 0, n_stop = 0;

    initial begin
        sda_out = 1'b1;
        for (int i = 0; i < 16; i++) mem[i] = 8'h00;
        mem[5] = 8'hA1; mem[6] = 8'hB2; mem[7] = 8'hC3;
        #1;                       // ignore the start-up edge at time 0
        n_start = 0; n_stop = 0;
    end

    always @(negedge sda_in) if (scl) begin        // START or repeated START
        st = ADDRX; bcnt = 0; sh = 8'd0; sda_out = 1'b1; n_start++;
    end

    always @(posedge sda_in) if (scl) begin        // STOP
        st = IDLE; sda_out = 1'b1; n_stop++;
    end

    always @(posedge scl) begin                    // sample on rising SCL
        case (st)
            ADDRX, WRDATA: begin sh = {sh[6:0], sda_in}; bcnt++; end
            WAIT_ACK:      ack_m = ~sda_in;
            default: ;
        endcase
    end

    always @(negedge scl) begin                    // change SDA on falling SCL
        case (st)
            ADDRX: if (bcnt == 8) begin
                if (sh[7:1] == ADDR) begin rw = sh[0]; sda_out = 1'b0; st = ACK_A; end
                else st = IDLE;                    // not for us: leave SDA released (NACK)
            end
            ACK_A: begin
                sda_out = 1'b1; bcnt = 0;
                if (rw) begin sh = mem[ptr]; ptr++; sent = 0; sda_out = sh[7]; st = RDDATA; end
                else    begin first = 1'b1; st = WRDATA; end
            end
            WRDATA: if (bcnt == 8) begin
                if (first) begin ptr = sh[3:0]; first = 1'b0; end
                else       begin mem[ptr] = sh; ptr++; end
                sda_out = 1'b0; st = ACK_W;
            end
            ACK_W: begin sda_out = 1'b1; bcnt = 0; st = WRDATA; end
            RDDATA: begin
                sent++;
                if (sent == 8) begin sda_out = 1'b1; st = WAIT_ACK; end
                else begin sh = {sh[6:0], 1'b0}; sda_out = sh[7]; end
            end
            WAIT_ACK: begin
                if (ack_m) begin sh = mem[ptr]; ptr++; sent = 0; sda_out = sh[7]; st = RDDATA; end
                else begin st = IDLE; sda_out = 1'b1; end
            end
            default: ;
        endcase
    end

endmodule
