`timescale 1ns/1ps

// 32 x 32-bit register file: 2 async read ports, 1 sync write port, x0 = 0
module regfile (
    input  logic        clk,
    input  logic        we,
    input  logic [4:0]  rs1,
    input  logic [4:0]  rs2,
    input  logic [4:0]  rd,
    input  logic [31:0] wd,
    output logic [31:0] rd1,
    output logic [31:0] rd2
);

    logic [31:0] regs [0:31];

    initial begin
        for (int i = 0; i < 32; i++) regs[i] = 32'd0;
    end

    always_ff @(posedge clk) begin
        if (we && (rd != 5'd0))
            regs[rd] <= wd;
    end

    assign rd1 = (rs1 == 5'd0) ? 32'd0 : regs[rs1];
    assign rd2 = (rs2 == 5'd0) ? 32'd0 : regs[rs2];

endmodule
