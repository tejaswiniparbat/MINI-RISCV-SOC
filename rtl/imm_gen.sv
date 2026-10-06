`timescale 1ns/1ps

// RV32I immediate generator: picks the immediate format from the opcode
module imm_gen (
    input  logic [31:0] instr,
    output logic [31:0] imm
);

    always_comb begin
        case (instr[6:0])
            // I-type: OP-IMM, LOAD, JALR
            7'b0010011,
            7'b0000011,
            7'b1100111: imm = {{20{instr[31]}}, instr[31:20]};
            // S-type: STORE
            7'b0100011: imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            // B-type: BRANCH
            7'b1100011: imm = {{19{instr[31]}}, instr[31], instr[7],
                               instr[30:25], instr[11:8], 1'b0};
            // U-type: LUI, AUIPC
            7'b0110111,
            7'b0010111: imm = {instr[31:12], 12'b0};
            // J-type: JAL
            7'b1101111: imm = {{11{instr[31]}}, instr[31], instr[19:12],
                               instr[20], instr[30:21], 1'b0};
            default:    imm = 32'd0;
        endcase
    end

endmodule
