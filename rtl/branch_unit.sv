`timescale 1ns/1ps

// Branch condition evaluator (BEQ/BNE/BLT/BGE/BLTU/BGEU)
module branch_unit (
    input  logic [31:0] rs1,
    input  logic [31:0] rs2,
    input  logic [2:0]  funct3,
    input  logic        branch,     // from decoder
    output logic        taken
);

    logic cond;

    always_comb begin
        case (funct3)
            3'b000:  cond = (rs1 == rs2);
            3'b001:  cond = (rs1 != rs2);
            3'b100:  cond = ($signed(rs1) <  $signed(rs2));
            3'b101:  cond = ($signed(rs1) >= $signed(rs2));
            3'b110:  cond = (rs1 <  rs2);
            3'b111:  cond = (rs1 >= rs2);
            default: cond = 1'b0;
        endcase
    end

    assign taken = branch & cond;

endmodule
