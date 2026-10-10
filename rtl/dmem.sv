`timescale 1ns/1ps

// Data RAM: synchronous write, combinational read, byte/half/word access.
// funct3 follows RISC-V load/store encoding:
//   000 LB/SB   001 LH/SH   010 LW/SW   100 LBU   101 LHU
// Accesses are assumed naturally aligned.
module dmem #(
    parameter int DEPTH = 1024              // words
) (
    input  logic        clk,
    input  logic        we,
    input  logic [31:0] addr,
    input  logic [2:0]  funct3,
    input  logic [31:0] wdata,
    output logic [31:0] rdata
);

    localparam int AW = $clog2(DEPTH);

    logic [31:0] mem [0:DEPTH-1];
    logic [AW-1:0] widx;
    logic [31:0]   word, wshift;
    logic [3:0]    be;
    logic [7:0]    b;
    logic [15:0]   h;

    initial begin
        for (int i = 0; i < DEPTH; i++) mem[i] = 32'd0;
    end

    assign widx = addr[AW+1:2];
    assign word = mem[widx];

    // write: byte enables + data replicated into the right lanes
    always_comb begin
        case (funct3[1:0])
            2'b00:   begin be = 4'b0001 << addr[1:0];            wshift = {4{wdata[7:0]}};  end
            2'b01:   begin be = addr[1] ? 4'b1100 : 4'b0011;     wshift = {2{wdata[15:0]}}; end
            default: begin be = 4'b1111;                         wshift = wdata;            end
        endcase
    end

    always_ff @(posedge clk) begin
        for (int i = 0; i < 4; i++)
            if (we && be[i]) mem[widx][8*i +: 8] <= wshift[8*i +: 8];
    end

    // read: select lane, then sign/zero extend
    assign b = word[8*addr[1:0] +: 8];
    assign h = addr[1] ? word[31:16] : word[15:0];

    always_comb begin
        case (funct3)
            3'b000:  rdata = {{24{b[7]}},  b};
            3'b001:  rdata = {{16{h[15]}}, h};
            3'b100:  rdata = {24'b0, b};
            3'b101:  rdata = {16'b0, h};
            default: rdata = word;
        endcase
    end

endmodule
