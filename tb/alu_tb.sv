`timescale 1ns/1ps

module alu_tb;

    logic [31:0] a, b, result;
    logic [3:0]  alu_op;
    logic        zero;
    int          errors = 0;
    int          tests  = 0;

    alu dut (.a(a), .b(b), .alu_op(alu_op), .result(result), .zero(zero));

    task automatic check(
        input logic [3:0]  op,
        input logic [31:0] in_a,
        input logic [31:0] in_b,
        input logic [31:0] expected,
        input string       name
    );
        alu_op = op; a = in_a; b = in_b;
        #10;
        tests++;
        if (result !== expected || zero !== (expected == 32'd0)) begin
            errors++;
            $display("FAIL %-5s a=%h b=%h got=%h zero=%b expected=%h",
                     name, in_a, in_b, result, zero, expected);
        end else
            $display("PASS %-5s a=%h b=%h result=%h", name, in_a, in_b, result);
    endtask

    initial begin
        check(4'b0000, 32'd10,       32'd5,        32'd15,       "ADD");
        check(4'b0001, 32'd10,       32'd5,        32'd5,        "SUB");
        check(4'b0010, 32'hFF00FF00, 32'h0F0F0F0F, 32'h0F000F00, "AND");
        check(4'b0011, 32'hFF00FF00, 32'h0F0F0F0F, 32'hFF0FFF0F, "OR");
        check(4'b0100, 32'hFF00FF00, 32'h0F0F0F0F, 32'hF00FF00F, "XOR");
        check(4'b0101, 32'd1,        32'd4,        32'd16,       "SLL");
        check(4'b0110, 32'd16,       32'd2,        32'd4,        "SRL");
        check(4'b0111, 32'h80000000, 32'd4,        32'hF8000000, "SRA");
        check(4'b1000, 32'd5,        32'd10,       32'd1,        "SLT");
        check(4'b1001, 32'd10,       32'd5,        32'd0,        "SLTU");
        check(4'b1000, 32'hFFFFFFFF, 32'd1,        32'd1,        "SLT-");
        check(4'b1001, 32'hFFFFFFFF, 32'd1,        32'd0,        "SLTU-");
        check(4'b0000, 32'hFFFFFFFF, 32'd1,        32'd0,        "ADDwr");
        check(4'b0101, 32'd1,        32'd32,       32'd1,        "SLL32");

        if (errors == 0) $display("ALL %0d TESTS PASSED", tests);
        else             $display("%0d of %0d TESTS FAILED", errors, tests);
        $finish;
    end

    initial begin
        $dumpfile("waves/alu_tb.vcd");
        $dumpvars(0, alu_tb);
    end

endmodule
