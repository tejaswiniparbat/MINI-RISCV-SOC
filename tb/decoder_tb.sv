`timescale 1ns/1ps

module decoder_tb;

    logic [31:0] instr;
    logic        reg_write, mem_read, mem_write, branch, jal, jalr, b_imm, illegal;
    logic [1:0]  a_sel, wb_sel;
    logic [3:0]  alu_op;
    int errors = 0, tests = 0;

    decoder dut (.*);

    // Expected: rw=reg_write mr=mem_read mw=mem_write br=branch jl=jal jr=jalr
    //           bi=b_imm, a=a_sel, wb=wb_sel, op=alu_op, il=illegal
    task automatic chk(
        input logic [31:0] ins, input string name,
        input logic rw, mr, mw, br, jl, jr, bi,
        input logic [1:0] a, wb,
        input logic [3:0] op,
        input logic il
    );
        logic [15:0] got, exp;
        instr = ins;
        #1;
        tests++;
        got = {reg_write, mem_read, mem_write, branch, jal, jalr, b_imm, a_sel, wb_sel, alu_op, illegal};
        exp = {rw, mr, mw, br, jl, jr, bi, a, wb, op, il};
        if (got !== exp) begin
            errors++;
            $display("FAIL %-8s instr=%h got=%b expected=%b", name, ins, got, exp);
        end else
            $display("PASS %-8s instr=%h", name, ins);
    endtask

    initial begin
        //                           rw mr mw br jl jr bi  a   wb   op     il
        chk(32'h003100B3, "add",     1, 0, 0, 0, 0, 0, 0, 0, 0, 4'b0000, 0);
        chk(32'h403100B3, "sub",     1, 0, 0, 0, 0, 0, 0, 0, 0, 4'b0001, 0);
        chk(32'h003170B3, "and",     1, 0, 0, 0, 0, 0, 0, 0, 0, 4'b0010, 0);
        chk(32'h003160B3, "or",      1, 0, 0, 0, 0, 0, 0, 0, 0, 4'b0011, 0);
        chk(32'h003140B3, "xor",     1, 0, 0, 0, 0, 0, 0, 0, 0, 4'b0100, 0);
        chk(32'h003110B3, "sll",     1, 0, 0, 0, 0, 0, 0, 0, 0, 4'b0101, 0);
        chk(32'h003150B3, "srl",     1, 0, 0, 0, 0, 0, 0, 0, 0, 4'b0110, 0);
        chk(32'h403150B3, "sra",     1, 0, 0, 0, 0, 0, 0, 0, 0, 4'b0111, 0);
        chk(32'h003120B3, "slt",     1, 0, 0, 0, 0, 0, 0, 0, 0, 4'b1000, 0);
        chk(32'h003130B3, "sltu",    1, 0, 0, 0, 0, 0, 0, 0, 0, 4'b1001, 0);
        chk(32'h00510093, "addi",    1, 0, 0, 0, 0, 0, 1, 0, 0, 4'b0000, 0);
        chk(32'h00311093, "slli",    1, 0, 0, 0, 0, 0, 1, 0, 0, 4'b0101, 0);
        chk(32'h40315093, "srai",    1, 0, 0, 0, 0, 0, 1, 0, 0, 4'b0111, 0);
        chk(32'h00812083, "lw",      1, 1, 0, 0, 0, 0, 1, 0, 1, 4'b0000, 0);
        chk(32'h00312423, "sw",      0, 0, 1, 0, 0, 0, 1, 0, 0, 4'b0000, 0);
        chk(32'h00208463, "beq",     0, 0, 0, 1, 0, 0, 0, 0, 0, 4'b0000, 0);
        chk(32'h010000EF, "jal",     1, 0, 0, 0, 1, 0, 0, 0, 2, 4'b0000, 0);
        chk(32'h004100E7, "jalr",    1, 0, 0, 0, 0, 1, 1, 0, 2, 4'b0000, 0);
        chk(32'h123450B7, "lui",     1, 0, 0, 0, 0, 0, 1, 2, 0, 4'b0000, 0);
        chk(32'h12345097, "auipc",   1, 0, 0, 0, 0, 0, 1, 1, 0, 4'b0000, 0);
        chk(32'hFFFFFFFF, "illegal", 0, 0, 0, 0, 0, 0, 0, 0, 0, 4'b0000, 1);

        if (errors == 0) $display("ALL %0d TESTS PASSED", tests);
        else             $display("%0d of %0d TESTS FAILED", errors, tests);
        $finish;
    end

endmodule
