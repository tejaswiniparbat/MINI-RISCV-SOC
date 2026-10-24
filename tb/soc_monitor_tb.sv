`timescale 1ns/1ps

// Types commands into firmware/monitor.hex running on the SoC (like a person at a serial terminal)
// and compares the complete conversation, including the echo of what was typed.
module soc_monitor_tb;

    localparam int DIV    = 10;                // clocks per UART bit (CLK_HZ/BAUD)
    localparam int BIT_NS = DIV * 10;          // 10 ns clock
    localparam string CRLF = "\015\012";       // CR LF written as octal escapes
    localparam string BS3  = "\010 \010";      // erase one character on a terminal

    logic        clk = 1'b0;
    logic        rst = 1'b1;
    logic [15:0] gpio_in = 16'h0000, gpio_out;
    logic        uart_tx;
    logic        uart_rx = 1'b1;
    string       msg = "";
    int errors = 0, tests = 0;

    soc_top #(.INIT_FILE("firmware/monitor.hex"), .CLK_HZ(1000), .BAUD(100)) dut (
        .clk(clk), .rst(rst), .gpio_in(gpio_in), .gpio_out(gpio_out),
        .uart_tx(uart_tx), .uart_rx(uart_rx),
        .spi_sclk(), .spi_mosi(), .spi_miso(1'b0), .spi_cs_n(),
        .i2c_scl_o(), .i2c_sda_o(), .i2c_sda_i(1'b1)
    );

    always #5 clk = ~clk;

    // Receiver model on the TX pin: everything the monitor prints is collected in msg
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
        end
    end

    // "Keyboard"
    task automatic type_char(input logic [7:0] b);
        uart_rx = 1'b0; #(BIT_NS);
        for (int i = 0; i < 8; i++) begin
            uart_rx = b[i]; #(BIT_NS);
        end
        uart_rx = 1'b1; #(BIT_NS);
        #(3 * BIT_NS);                         // gap between keystrokes
    endtask

    task automatic type_text(input string s);
        for (int i = 0; i < s.len(); i++) type_char(8'(s.getc(i)));
    endtask

    task automatic type_line(input string s);
        type_text(s);
        type_char(8'h0D);                      // Enter sends CR
    endtask

    // wait until the monitor has printed its prompt again: a "> " that follows a line break
    // (the help text contains "<addr> " so a bare "> " is not enough)
    task automatic wait_prompt();
        int guard = 0;
        while (!(msg.len() >= 4 && msg.substr(msg.len() - 4, msg.len() - 1) == {CRLF, "> "}) && guard < 60000) begin
            @(posedge clk);
            guard++;
        end
    endtask

    task automatic check(input string name, input logic [31:0] got, input logic [31:0] exp);
        tests++;
        if (got !== exp) begin errors++; $display("FAIL %-22s got=%h expected=%h", name, got, exp); end
        else $display("PASS %-22s = %h", name, got);
    endtask

    string expected;

    initial begin
        repeat (3) @(posedge clk);
        @(negedge clk) rst = 1'b0;

        wait_prompt();                                   // banner
        type_line("w A00 DEADBEEF");   wait_prompt();
        type_line("r A00");            wait_prompt();
        type_line("w A04 0x12345678"); wait_prompt();
        type_line("r A00 2");          wait_prompt();
        type_line("led a5");           wait_prompt();
        check("LEDs after 'led a5'", 32'(gpio_out), 32'h00A5);
        gpio_in = 16'h1234;
        type_line("sw");               wait_prompt();
        type_line("bogus");            wait_prompt();
        type_line("r zz");             wait_prompt();
        type_text("r A0X"); type_char(8'h08); type_text("0"); type_char(8'h0D);   // typo fixed with backspace
        wait_prompt();
        type_line("h");                wait_prompt();

        expected = {CRLF, "MINI-RISKV-SOC monitor. Type h for help.", CRLF, "> ",
                    "w A00 DEADBEEF", CRLF, "ok", CRLF, "> ",
                    "r A00", CRLF, "00000A00: DEADBEEF", CRLF, "> ",
                    "w A04 0x12345678", CRLF, "ok", CRLF, "> ",
                    "r A00 2", CRLF, "00000A00: DEADBEEF", CRLF, "00000A04: 12345678", CRLF, "> ",
                    "led a5", CRLF, "ok", CRLF, "> ",
                    "sw", CRLF, "00001234", CRLF, "> ",
                    "bogus", CRLF, "?", CRLF, "> ",
                    "r zz", CRLF, "?", CRLF, "> ",
                    "r A0X", BS3, "0", CRLF, "00000A00: DEADBEEF", CRLF, "> ",
                    "h", CRLF,
                    "r <addr> [n]   read n words", CRLF,
                    "w <addr> <val> write word", CRLF,
                    "led <val>      set LEDs", CRLF,
                    "sw             read switches", CRLF, "> "};

        check("memory 0xA00",     dut.u_core.u_dmem.mem[640], 32'hDEADBEEF);
        check("memory 0xA04",     dut.u_core.u_dmem.mem[641], 32'h12345678);
        check("transcript length", 32'(msg.len()), 32'(expected.len()));
        check("transcript matches", 32'(msg == expected), 32'd1);
        if (msg != expected) begin
            for (int i = 0; i < expected.len() && i < msg.len(); i++)
                if (msg.getc(i) != expected.getc(i)) begin
                    $display("first difference at index %0d: got %02h expected %02h", i, msg.getc(i), expected.getc(i));
                    break;
                end
        end

        if (errors == 0) $display("ALL %0d TESTS PASSED", tests);
        else             $display("%0d of %0d TESTS FAILED", errors, tests);
        $finish;
    end

endmodule
