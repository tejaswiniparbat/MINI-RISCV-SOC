`timescale 1ns/1ps

module dmem_tb;

    logic        clk = 1'b0;
    logic        we  = 1'b0;
    logic [31:0] addr = '0, wdata = '0, rdata;
    logic [2:0]  funct3 = 3'b010;
    int errors = 0, tests = 0;

    dmem #(.DEPTH(64)) dut (.clk(clk), .we(we), .addr(addr), .funct3(funct3),
                            .wdata(wdata), .rdata(rdata));

    always #5 clk = ~clk;

    task automatic store(input logic [31:0] a, input logic [2:0] f3, input logic [31:0] d);
        @(negedge clk);
        we = 1'b1; addr = a; funct3 = f3; wdata = d;
        @(negedge clk);
        we = 1'b0;
    endtask

    task automatic load(input logic [31:0] a, input logic [2:0] f3,
                        input logic [31:0] exp, input string name);
        addr = a; funct3 = f3;
        #1;
        tests++;
        if (rdata !== exp) begin
            errors++;
            $display("FAIL %-10s addr=%h got=%h expected=%h", name, a, rdata, exp);
        end else
            $display("PASS %-10s addr=%h data=%h", name, a, rdata);
    endtask

    initial begin
        store(32'h10, 3'b010, 32'hDEADBEEF);
        load (32'h10, 3'b010, 32'hDEADBEEF, "lw");
        load (32'h10, 3'b000, 32'hFFFFFFEF, "lb +0");
        load (32'h11, 3'b000, 32'hFFFFFFBE, "lb +1");
        load (32'h12, 3'b000, 32'hFFFFFFAD, "lb +2");
        load (32'h13, 3'b000, 32'hFFFFFFDE, "lb +3");
        load (32'h10, 3'b100, 32'h000000EF, "lbu +0");
        load (32'h13, 3'b100, 32'h000000DE, "lbu +3");
        load (32'h10, 3'b001, 32'hFFFFBEEF, "lh +0");
        load (32'h12, 3'b001, 32'hFFFFDEAD, "lh +2");
        load (32'h10, 3'b101, 32'h0000BEEF, "lhu +0");
        load (32'h12, 3'b101, 32'h0000DEAD, "lhu +2");

        store(32'h11, 3'b000, 32'hFFFFFF55);        // sb: only low byte stored
        load (32'h10, 3'b010, 32'hDEAD55EF, "sb 0x11");
        store(32'h12, 3'b001, 32'hFFFF1234);        // sh: only low half stored
        load (32'h10, 3'b010, 32'h123455EF, "sh 0x12");
        store(32'h10, 3'b000, 32'hFFFFFF7F);
        load (32'h10, 3'b000, 32'h0000007F, "lb positive");
        load (32'h10, 3'b010, 32'h1234557F, "lw after sb");
        load (32'h14, 3'b010, 32'h00000000, "neighbour=0");

        if (errors == 0) $display("ALL %0d TESTS PASSED", tests);
        else             $display("%0d of %0d TESTS FAILED", errors, tests);
        $finish;
    end

endmodule
