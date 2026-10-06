`timescale 1ns/1ps

module imm_gen_tb;

    logic [31:0] instr, imm;
    int errors = 0, tests = 0;

    imm_gen dut (.instr(instr), .imm(imm));

    task automatic check(input logic [31:0] ins, input logic [31:0] exp, input string name);
        instr = ins;
        #1;
        tests++;
        if (imm !== exp) begin
            errors++;
            $display("FAIL %-14s instr=%h got=%h expected=%h", name, ins, imm, exp);
        end else
            $display("PASS %-14s instr=%h imm=%h", name, ins, imm);
    endtask

    initial begin
        check(32'h00510093, 32'h00000005, "addi +5");
        check(32'hFFF10093, 32'hFFFFFFFF, "addi -1");
        check(32'h00812083, 32'h00000008, "lw 8(x2)");
        check(32'h004100E7, 32'h00000004, "jalr 4");
        check(32'h00312423, 32'h00000008, "sw 8(x2)");
        check(32'hFE312E23, 32'hFFFFFFFC, "sw -4(x2)");
        check(32'h00208463, 32'h00000008, "beq +8");
        check(32'hFE000EE3, 32'hFFFFFFFC, "beq -4");
        check(32'h123450B7, 32'h12345000, "lui");
        check(32'h12345097, 32'h12345000, "auipc");
        check(32'h010000EF, 32'h00000010, "jal +16");
        check(32'hFF9FF06F, 32'hFFFFFFF8, "jal -8");
        check(32'h003100B3, 32'h00000000, "add (no imm)");

        if (errors == 0) $display("ALL %0d TESTS PASSED", tests);
        else             $display("%0d of %0d TESTS FAILED", errors, tests);
        $finish;
    end

endmodule
