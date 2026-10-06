`timescale 1ns/1ps

// RV32I control decoder (single-cycle core)
//   a_sel : 00 = rs1, 01 = PC, 10 = zero
//   b_imm : 0 = rs2, 1 = immediate
//   wb_sel: 00 = ALU result, 01 = load data, 10 = PC+4
// Branch conditions (BEQ/BNE/BLT/...) are resolved later using funct3.
module decoder (
    input  logic [31:0] instr,
    output logic        reg_write,
    output logic        mem_read,
    output logic        mem_write,
    output logic        branch,
    output logic        jal,
    output logic        jalr,
    output logic        b_imm,
    output logic [1:0]  a_sel,
    output logic [1:0]  wb_sel,
    output logic [3:0]  alu_op,
    output logic        illegal
);

    localparam logic [3:0] ALU_ADD  = 4'b0000, ALU_SUB  = 4'b0001,
                           ALU_AND  = 4'b0010, ALU_OR   = 4'b0011,
                           ALU_XOR  = 4'b0100, ALU_SLL  = 4'b0101,
                           ALU_SRL  = 4'b0110, ALU_SRA  = 4'b0111,
                           ALU_SLT  = 4'b1000, ALU_SLTU = 4'b1001;

    logic [6:0] opcode;
    logic [2:0] funct3;
    logic       f7_5;      // instr[30]: selects SUB/SRA

    assign opcode = instr[6:0];
    assign funct3 = instr[14:12];
    assign f7_5   = instr[30];

    // ALU operation for OP (R-type) and OP-IMM (I-type) instructions
    function automatic logic [3:0] alu_from_funct(
        input logic [2:0] f3, input logic f75, input logic is_rtype
    );
        case (f3)
            3'b000:  alu_from_funct = (is_rtype && f75) ? ALU_SUB : ALU_ADD;
            3'b001:  alu_from_funct = ALU_SLL;
            3'b010:  alu_from_funct = ALU_SLT;
            3'b011:  alu_from_funct = ALU_SLTU;
            3'b100:  alu_from_funct = ALU_XOR;
            3'b101:  alu_from_funct = f75 ? ALU_SRA : ALU_SRL;
            3'b110:  alu_from_funct = ALU_OR;
            default: alu_from_funct = ALU_AND;
        endcase
    endfunction

    always_comb begin
        // defaults
        reg_write = 1'b0;  mem_read = 1'b0;  mem_write = 1'b0;
        branch    = 1'b0;  jal      = 1'b0;  jalr      = 1'b0;
        b_imm     = 1'b0;  a_sel    = 2'b00; wb_sel    = 2'b00;
        alu_op    = ALU_ADD;
        illegal   = 1'b0;

        case (opcode)
            7'b0110011: begin  // OP: R-type
                reg_write = 1'b1;
                alu_op    = alu_from_funct(funct3, f7_5, 1'b1);
            end
            7'b0010011: begin  // OP-IMM
                reg_write = 1'b1;
                b_imm     = 1'b1;
                alu_op    = alu_from_funct(funct3, f7_5, 1'b0);
            end
            7'b0000011: begin  // LOAD
                reg_write = 1'b1;
                mem_read  = 1'b1;
                b_imm     = 1'b1;
                wb_sel    = 2'b01;
            end
            7'b0100011: begin  // STORE
                mem_write = 1'b1;
                b_imm     = 1'b1;
            end
            7'b1100011: begin  // BRANCH
                branch    = 1'b1;
            end
            7'b1101111: begin  // JAL
                reg_write = 1'b1;
                jal       = 1'b1;
                wb_sel    = 2'b10;
            end
            7'b1100111: begin  // JALR
                reg_write = 1'b1;
                jalr      = 1'b1;
                b_imm     = 1'b1;
                wb_sel    = 2'b10;
            end
            7'b0110111: begin  // LUI: 0 + imm
                reg_write = 1'b1;
                b_imm     = 1'b1;
                a_sel     = 2'b10;
            end
            7'b0010111: begin  // AUIPC: PC + imm
                reg_write = 1'b1;
                b_imm     = 1'b1;
                a_sel     = 2'b01;
            end
            default: illegal = 1'b1;
        endcase
    end

endmodule
