`timescale 1ns/1ps

// Runs a hand-assembled program on the core and checks registers + memory.
//   x1 = sum of 1..10 (loop), stored to and reloaded from address 0x100
//   jal links x6 and skips one instruction; lui+addi builds 0x12345678
module core_tb;

    logic        clk = 1'b0;
    logic        rst = 1'b1;
    logic [31:0] pc;
    int errors = 0, tests = 0;

    core #(.IMEM_DEPTH(64), .DMEM_DEPTH(128)) dut (.clk(clk), .rst(rst), .pc_out(pc), .io_we(), .io_addr(), .io_wdata(), .io_rdata(32'd0));

    always #5 clk = ~clk;

    task automatic check(input string name, input logic [31:0] got, input logic [31:0] exp);
        tests++;
        if (got !== exp) begin
            errors++;
            $display("FAIL %-14s got=%h expected=%h", name, got, exp);
        end else
            $display("PASS %-14s = %h", name, got);
    endtask

    initial begin
        #1;  // let the memories finish their own initial blocks first
        dut.u_imem.mem[0]  = 32'h00000093;  // 00: addi x1,x0,0
        dut.u_imem.mem[1]  = 32'h00100113;  // 04: addi x2,x0,1
        dut.u_imem.mem[2]  = 32'h00B00193;  // 08: addi x3,x0,11
        dut.u_imem.mem[3]  = 32'h002080B3;  // 0C: add  x1,x1,x2      <- loop
        dut.u_imem.mem[4]  = 32'h00110113;  // 10: addi x2,x2,1
        dut.u_imem.mem[5]  = 32'hFE314CE3;  // 14: blt  x2,x3,-8
        dut.u_imem.mem[6]  = 32'h10102023;  // 18: sw   x1,0x100(x0)
        dut.u_imem.mem[7]  = 32'h10002203;  // 1C: lw   x4,0x100(x0)
        dut.u_imem.mem[8]  = 32'h0080036F;  // 20: jal  x6,+8
        dut.u_imem.mem[9]  = 32'h06300393;  // 24: addi x7,x0,99      (skipped)
        dut.u_imem.mem[10] = 32'h123452B7;  // 28: lui  x5,0x12345
        dut.u_imem.mem[11] = 32'h67828293;  // 2C: addi x5,x5,0x678
        dut.u_imem.mem[12] = 32'h0000006F;  // 30: jal  x0,0          (halt)

        repeat (3) @(posedge clk);
        @(negedge clk) rst = 1'b0;
        repeat (100) @(posedge clk);
        #1;

        check("x1  sum 1..10",  dut.u_regfile.regs[1], 32'd55);
        check("x2  counter",    dut.u_regfile.regs[2], 32'd11);
        check("x3  limit",      dut.u_regfile.regs[3], 32'd11);
        check("x4  lw result",  dut.u_regfile.regs[4], 32'd55);
        check("x5  lui+addi",   dut.u_regfile.regs[5], 32'h12345678);
        check("x6  jal link",   dut.u_regfile.regs[6], 32'h00000024);
        check("x7  skipped",    dut.u_regfile.regs[7], 32'd0);
        check("mem[0x100]",     dut.u_dmem.mem[64],    32'd55);
        check("pc halted",      pc,                    32'h00000030);

        if (errors == 0) $display("ALL %0d TESTS PASSED", tests);
        else             $display("%0d of %0d TESTS FAILED", errors, tests);
        $finish;
    end

endmodule
