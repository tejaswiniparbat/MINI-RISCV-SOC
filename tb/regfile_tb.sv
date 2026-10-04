`timescale 1ns/1ps

module regfile_tb;

    logic        clk = 1'b0;
    logic        we  = 1'b0;
    logic [4:0]  rs1 = '0, rs2 = '0, rd = '0;
    logic [31:0] wd = '0, rd1, rd2;
    int          errors = 0;
    int          tests  = 0;

    regfile dut (.clk(clk), .we(we), .rs1(rs1), .rs2(rs2), .rd(rd),
                 .wd(wd), .rd1(rd1), .rd2(rd2));

    always #5 clk = ~clk;

    task automatic write_reg(input logic [4:0] r, input logic [31:0] v);
        @(negedge clk);
        we = 1'b1; rd = r; wd = v;
        @(negedge clk);
        we = 1'b0;
    endtask

    task automatic check_read(
        input logic [4:0]  r1, input logic [4:0]  r2,
        input logic [31:0] e1, input logic [31:0] e2,
        input string       name
    );
        rs1 = r1; rs2 = r2;
        #1;
        tests++;
        if (rd1 !== e1 || rd2 !== e2) begin
            errors++;
            $display("FAIL %s: rd1=%h (exp %h) rd2=%h (exp %h)", name, rd1, e1, rd2, e2);
        end else
            $display("PASS %s", name);
    endtask

    initial begin
        write_reg(5'd5, 32'hDEADBEEF);
        check_read(5'd5, 5'd0, 32'hDEADBEEF, 32'h0, "write x5, read x5 and x0");

        write_reg(5'd0, 32'hFFFFFFFF);
        check_read(5'd0, 5'd0, 32'h0, 32'h0, "write to x0 is ignored");

        write_reg(5'd10, 32'h12345678);
        check_read(5'd5, 5'd10, 32'hDEADBEEF, 32'h12345678, "two read ports");

        @(negedge clk);
        we = 1'b0; rd = 5'd5; wd = 32'h0;
        @(negedge clk);
        check_read(5'd5, 5'd5, 32'hDEADBEEF, 32'hDEADBEEF, "we=0 does not write");

        for (int i = 1; i < 32; i++)
            write_reg(5'(i), i * 32'h01010101);
        for (int i = 1; i < 32; i++)
            check_read(5'(i), 5'(32 - i), i * 32'h01010101, (32 - i) * 32'h01010101, "all-registers sweep");

        if (errors == 0) $display("ALL %0d TESTS PASSED", tests);
        else             $display("%0d of %0d TESTS FAILED", errors, tests);
        $finish;
    end

endmodule
