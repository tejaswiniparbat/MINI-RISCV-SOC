`timescale 1ns/1ps

// Single-cycle RV32I core: PC -> imem -> decoder/regfile/imm_gen -> ALU -> dmem -> writeback
module core #(
    parameter int    IMEM_DEPTH = 1024,     // words
    parameter int    DMEM_DEPTH = 1024,     // words
    parameter string INIT_FILE  = ""        // hex program for imem
) (
    input  logic        clk,
    input  logic        rst,
    output logic [31:0] pc_out
);

    logic [31:0] pc, pc_plus4, next_pc, instr, imm;
    logic        reg_write, mem_read, mem_write, branch, jal, jalr, b_imm, illegal;
    logic [1:0]  a_sel, wb_sel;
    logic [3:0]  alu_op;
    logic [31:0] rs1_val, rs2_val, alu_a, alu_b, alu_result, mem_rdata, wb_data;
    logic        alu_zero, br_taken;

    assign pc_plus4 = pc + 32'd4;
    assign pc_out   = pc;

    // ---------------- fetch ----------------
    imem #(.DEPTH(IMEM_DEPTH), .INIT_FILE(INIT_FILE)) u_imem (
        .addr(pc), .instr(instr)
    );

    // ---------------- decode ----------------
    decoder u_decoder (.*);                       // ports share names with the signals above
    imm_gen u_imm_gen (.instr(instr), .imm(imm));

    regfile u_regfile (
        .clk(clk),
        .we (reg_write & ~rst),
        .rs1(instr[19:15]),
        .rs2(instr[24:20]),
        .rd (instr[11:7]),
        .wd (wb_data),
        .rd1(rs1_val),
        .rd2(rs2_val)
    );

    // ---------------- execute ----------------
    always_comb begin
        case (a_sel)
            2'b01:   alu_a = pc;
            2'b10:   alu_a = 32'd0;
            default: alu_a = rs1_val;
        endcase
    end

    assign alu_b = b_imm ? imm : rs2_val;

    alu u_alu (
        .a(alu_a), .b(alu_b), .alu_op(alu_op),
        .result(alu_result), .zero(alu_zero)
    );

    branch_unit u_branch (
        .rs1(rs1_val), .rs2(rs2_val), .funct3(instr[14:12]),
        .branch(branch), .taken(br_taken)
    );

    // ---------------- memory ----------------
    dmem #(.DEPTH(DMEM_DEPTH)) u_dmem (
        .clk(clk),
        .we (mem_write & ~rst),
        .addr(alu_result),
        .funct3(instr[14:12]),
        .wdata(rs2_val),
        .rdata(mem_rdata)
    );

    // ---------------- writeback ----------------
    always_comb begin
        case (wb_sel)
            2'b01:   wb_data = mem_rdata;
            2'b10:   wb_data = pc_plus4;
            default: wb_data = alu_result;
        endcase
    end

    // ---------------- next PC ----------------
    always_comb begin
        if (jalr)                  next_pc = {alu_result[31:1], 1'b0};
        else if (jal || br_taken)  next_pc = pc + imm;
        else                       next_pc = pc_plus4;
    end

    always_ff @(posedge clk) begin
        if (rst) pc <= 32'd0;
        else     pc <= next_pc;
    end

endmodule
