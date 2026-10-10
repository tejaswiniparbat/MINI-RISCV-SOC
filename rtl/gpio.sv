`timescale 1ns/1ps

// Memory-mapped GPIO.  Register offsets (word access):
//   0x00  OUT  (read/write)  drives pins_out (LEDs)
//   0x04  IN   (read only)   samples pins_in (switches/buttons), 2-FF synchronised
module gpio #(
    parameter int W = 16
) (
    input  logic         clk,
    input  logic         rst,
    input  logic         we,
    input  logic [31:0]  addr,
    input  logic [31:0]  wdata,
    output logic [31:0]  rdata,
    input  logic [W-1:0] pins_in,
    output logic [W-1:0] pins_out
);

    logic [W-1:0] out_reg = '0;
    logic [W-1:0] in_s1 = '0, in_s2 = '0;

    always_ff @(posedge clk) begin
        in_s1 <= pins_in;
        in_s2 <= in_s1;
        if (rst)                              out_reg <= '0;
        else if (we && addr[3:2] == 2'd0)     out_reg <= wdata[W-1:0];
    end

    always_comb begin
        case (addr[3:2])
            2'd0:    rdata = 32'(out_reg);
            2'd1:    rdata = 32'(in_s2);
            default: rdata = 32'd0;
        endcase
    end

    assign pins_out = out_reg;

endmodule
