`timescale 1ns/1ps

// Runs firmware/uart_demo.hex on the whole SoC and decodes what comes out of the UART pin.
module soc_uart_tb;

    localparam int DIV    = 10;                // clocks per UART bit (CLK_HZ/BAUD)
    localparam int BIT_NS = DIV * 10;          // 10 ns clock

    logic        clk = 1'b0;
    logic        rst = 1'b1;
    logic [15:0] gpio_out;
    logic        uart_tx;
    string       msg = "";
    int          nrx = 0;
    int errors = 0, tests = 0;

    soc_top #(.INIT_FILE("firmware/uart_demo.hex"), .CLK_HZ(1000), .BAUD(100)) dut (
        .clk(clk), .rst(rst), .gpio_in(16'h0000), .gpio_out(gpio_out), .uart_tx(uart_tx)
    );

    always #5 clk = ~clk;

    // Serial receiver model: finds each start bit, samples every bit in the middle
    initial begin : rx_proc
        logic [7:0] b;
        forever begin
            @(negedge uart_tx);
            #(BIT_NS + BIT_NS / 2);
            for (int i = 0; i < 8; i++) begin
                b[i] = uart_tx;
                #(BIT_NS);
            end
            msg = $sformatf("%s%c", msg, b);
            nrx++;
        end
    end

    task automatic check(input string name, input logic [31:0] got, input logic [31:0] exp);
        tests++;
        if (got !== exp) begin errors++; $display("FAIL %-18s got=%0d expected=%0d", name, got, exp); end
        else $display("PASS %-18s = %0d", name, got);
    endtask

    string expected = "Hello, RISC-V!\nDEADBEEF\n";
    int    bad;

    initial begin
        repeat (3) @(posedge clk);
        @(negedge clk) rst = 1'b0;
        repeat (8000) @(posedge clk);
        #1;

        $display("UART says: %s", msg);

        bad = 0;
        for (int i = 0; i < expected.len(); i++)
            if (i >= msg.len() || msg.getc(i) != expected.getc(i)) bad++;

        check("characters received", 32'(nrx), 32'(expected.len()));
        check("wrong characters",    32'(bad), 32'd0);

        if (errors == 0) $display("ALL %0d TESTS PASSED", tests);
        else             $display("%0d of %0d TESTS FAILED", errors, tests);
        $finish;
    end

endmodule
