`timescale 1ns/1ps

// Instruction ROM: word-addressed storage, byte address in, 32-bit instruction out.
// Unwritten locations read as NOP (addi x0,x0,0). Optional hex file via INIT_FILE.
module imem #(
    parameter int    DEPTH     = 1024,      // words
    parameter string INIT_FILE = ""
) (
    input  logic [31:0] addr,
    output logic [31:0] instr
);

    localparam int AW = $clog2(DEPTH);

    logic [31:0] mem [0:DEPTH-1];

    initial begin
        for (int i = 0; i < DEPTH; i++) mem[i] = 32'h00000013;
        if (INIT_FILE != "") $readmemh(INIT_FILE, mem);
    end

    assign instr = mem[addr[AW+1:2]];

endmodule
