`timescale 1ns/1ps

module branch_unit_tb;

    logic [31:0] rs1, rs2;
    logic [2:0]  funct3;
    logic        branch, taken;
    int errors = 0, tests = 0;

    branch_unit dut (.rs1(rs1), .rs2(rs2), .funct3(funct3), .branch(branch), .taken(taken));

    task automatic check(input logic [2:0] f3, input logic [31:0] a, b,
                         input logic en, input logic exp, input string name);
        funct3 = f3; rs1 = a; rs2 = b; branch = en;
        #1;
        tests++;
        if (taken !== exp) begin
            errors++;
            $display("FAIL %-18s a=%h b=%h got=%b expected=%b", name, a, b, taken, exp);
        end else
            $display("PASS %-18s a=%h b=%h taken=%b", name, a, b, taken);
    endtask

    initial begin
        check(3'b000, 32'd5,        32'd5,        1, 1, "beq equal");
        check(3'b000, 32'd5,        32'd6,        1, 0, "beq not equal");
        check(3'b001, 32'd5,        32'd6,        1, 1, "bne differ");
        check(3'b001, 32'd5,        32'd5,        1, 0, "bne same");
        check(3'b100, 32'hFFFFFFFF, 32'd1,        1, 1, "blt -1<1");
        check(3'b100, 32'd1,        32'hFFFFFFFF, 1, 0, "blt 1<-1");
        check(3'b100, 32'd5,        32'd5,        1, 0, "blt equal");
        check(3'b101, 32'd1,        32'hFFFFFFFF, 1, 1, "bge 1>=-1");
        check(3'b101, 32'd5,        32'd5,        1, 1, "bge equal");
        check(3'b101, 32'hFFFFFFFF, 32'd1,        1, 0, "bge -1>=1");
        check(3'b110, 32'd1,        32'hFFFFFFFF, 1, 1, "bltu 1<max");
        check(3'b110, 32'hFFFFFFFF, 32'd1,        1, 0, "bltu max<1");
        check(3'b111, 32'hFFFFFFFF, 32'd1,        1, 1, "bgeu max>=1");
        check(3'b111, 32'd1,        32'hFFFFFFFF, 1, 0, "bgeu 1>=max");
        check(3'b000, 32'd5,        32'd5,        0, 0, "branch=0 blocks");
        check(3'b010, 32'd5,        32'd5,        1, 0, "invalid funct3");

        if (errors == 0) $display("ALL %0d TESTS PASSED", tests);
        else             $display("%0d of %0d TESTS FAILED", errors, tests);
        $finish;
    end

endmodule
