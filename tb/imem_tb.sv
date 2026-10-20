`timescale 1ns/1ps

module imem_tb;

    logic [31:0] addr, instr;
    int errors = 0, tests = 0;

    imem #(.DEPTH(64)) dut (.addr(addr), .instr(instr));

    task automatic check(input logic [31:0] a, input logic [31:0] exp, input string name);
        addr = a;
        #1;
        tests++;
        if (instr !== exp) begin
            errors++;
            $display("FAIL %-18s addr=%h got=%h expected=%h", name, a, instr, exp);
        end else
            $display("PASS %-18s addr=%h instr=%h", name, a, instr);
    endtask

    initial begin
        #1;  // let the memory finish its own initial block first
        // preload a few words directly (the core will use INIT_FILE instead)
        dut.mem[0] = 32'h00500093;   // addi x1,x0,5
        dut.mem[1] = 32'h00608113;   // addi x2,x1,6
        dut.mem[2] = 32'h002081B3;   // add  x3,x1,x2

        check(32'h00, 32'h00500093, "word 0");
        check(32'h04, 32'h00608113, "word 1");
        check(32'h08, 32'h002081B3, "word 2");
        check(32'h09, 32'h002081B3, "unaligned -> word 2");
        check(32'h0C, 32'h00000013, "unwritten = NOP");
        check(32'hFC, 32'h00000013, "last word = NOP");
        check(32'h100, 32'h00500093, "address wraps to 0");

        if (errors == 0) $display("ALL %0d TESTS PASSED", tests);
        else             $display("%0d of %0d TESTS FAILED", errors, tests);
        $finish;
    end

endmodule
