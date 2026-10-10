`timescale 1ns/1ps

// Runs the compiled C firmware (firmware/firmware.hex) on the core.
// main.c writes the first 10 Fibonacci numbers to 0x800.. and a marker to 0x828.
module core_fw_tb;

    logic        clk = 1'b0;
    logic        rst = 1'b1;
    logic [31:0] pc;
    int errors = 0, tests = 0;

    core #(.IMEM_DEPTH(1024), .DMEM_DEPTH(1024), .INIT_FILE("firmware/firmware.hex"))
        dut (.clk(clk), .rst(rst), .pc_out(pc));

    always #5 clk = ~clk;

    task automatic check(input string name, input logic [31:0] got, input logic [31:0] exp);
        tests++;
        if (got !== exp) begin
            errors++;
            $display("FAIL %-12s got=%h expected=%h", name, got, exp);
        end else
            $display("PASS %-12s = %h", name, got);
    endtask

    logic [31:0] pc_prev;

    initial begin
        repeat (3) @(posedge clk);
        @(negedge clk) rst = 1'b0;
        repeat (500) @(posedge clk);
        #1;

        check("fib[0]",  dut.u_dmem.mem[512 + 0], 32'd1);
        check("fib[1]",  dut.u_dmem.mem[512 + 1], 32'd1);
        check("fib[2]",  dut.u_dmem.mem[512 + 2], 32'd2);
        check("fib[3]",  dut.u_dmem.mem[512 + 3], 32'd3);
        check("fib[4]",  dut.u_dmem.mem[512 + 4], 32'd5);
        check("fib[5]",  dut.u_dmem.mem[512 + 5], 32'd8);
        check("fib[6]",  dut.u_dmem.mem[512 + 6], 32'd13);
        check("fib[7]",  dut.u_dmem.mem[512 + 7], 32'd21);
        check("fib[8]",  dut.u_dmem.mem[512 + 8], 32'd34);
        check("fib[9]",  dut.u_dmem.mem[512 + 9], 32'd55);
        check("done marker", dut.u_dmem.mem[512 + 10], 32'hC0DE600D);
        pc_prev = pc;
        @(posedge clk); #1;
        check("pc parked", pc, pc_prev);   // main() ended in its while(1) loop

        if (errors == 0) $display("ALL %0d TESTS PASSED", tests);
        else             $display("%0d of %0d TESTS FAILED", errors, tests);
        $finish;
    end

endmodule
