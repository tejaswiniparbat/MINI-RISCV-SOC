`timescale 1ns/1ps

// Whole-board test: fpga_top running firmware/board_demo_sim.hex.
// Checks reset, clock divider, switches->LEDs, walking LED, UART banner and UART echo.
module fpga_top_tb;

    localparam int BIT_NS = 200;               // sys clock = 20 ns, 10 clocks per UART bit

    logic        clk_in = 1'b0;
    logic        btn_rst = 1'b1;
    logic [15:0] sw = 16'h0000, led;
    logic        uart_rxd = 1'b1, uart_txd;
    logic        spi_sclk, spi_mosi, spi_cs_n;
    tri1         i2c_scl, i2c_sda;             // pulled-up lines
    string       msg = "";
    int          nrx = 0;
    int errors = 0, tests = 0;

    fpga_top #(.CLK_IN_HZ(2000), .CLK_DIV(2), .BAUD(100),
               .INIT_FILE("firmware/board_demo_sim.hex")) dut (
        .clk_in(clk_in), .btn_rst(btn_rst), .sw(sw), .led(led),
        .uart_rxd(uart_rxd), .uart_txd(uart_txd),
        .spi_sclk(spi_sclk), .spi_mosi(spi_mosi), .spi_miso(1'b0), .spi_cs_n(spi_cs_n),
        .i2c_scl(i2c_scl), .i2c_sda(i2c_sda)
    );

    always #5 clk_in = ~clk_in;

    // serial receiver on the TX pin
    initial begin : rx_proc
        logic [7:0] b;
        forever begin
            @(negedge uart_txd);
            #(BIT_NS + BIT_NS / 2);
            for (int i = 0; i < 8; i++) begin
                b[i] = uart_txd;
                #(BIT_NS);
            end
            msg = $sformatf("%s%c", msg, b);
            nrx++;
        end
    end

    // "keyboard" on the RX pin
    task automatic type_char(input logic [7:0] b);
        uart_rxd = 1'b0; #(BIT_NS);
        for (int i = 0; i < 8; i++) begin
            uart_rxd = b[i]; #(BIT_NS);
        end
        uart_rxd = 1'b1; #(BIT_NS);
    endtask

    task automatic check(input string name, input logic [31:0] got, input logic [31:0] exp);
        tests++;
        if (got !== exp) begin errors++; $display("FAIL %-24s got=%h expected=%h", name, got, exp); end
        else $display("PASS %-24s = %h", name, got);
    endtask

    logic [15:0] samples [0:5];
    int          onehot, distinct;
    string       expected = "MINI-RISKV-SOC ready\nA";

    initial begin
        // hold the reset button for a while, then let go
        #(10 * 40);
        btn_rst = 1'b0;

        // switch 0 up: LEDs mirror the switches
        sw = 16'h00F1;
        #(120_000);
        check("LEDs mirror switches", 32'(led), 32'h00F1);
        $display("UART says: %s", msg);

        // switch 0 down: walking LED
        sw = 16'h0000;
        #(30_000);
        for (int i = 0; i < 6; i++) begin
            #(25_000);
            samples[i] = led;
        end
        onehot = 0; distinct = 0;
        for (int i = 0; i < 6; i++) begin
            if (samples[i] != 16'h0 && (samples[i] & (samples[i] - 16'h1)) == 16'h0) onehot++;
            if (i > 0 && samples[i] != samples[i-1]) distinct++;
        end
        check("walking LED is one-hot", 32'(onehot), 32'd6);
        check("walking LED moves", 32'(distinct > 0), 32'd1);

        // typing 'a' must echo 'A'
        type_char("a");
        #(20_000);

        check("UART characters", 32'(nrx), 32'(expected.len()));
        check("UART text matches", 32'(msg == expected), 32'd1);

        if (errors == 0) $display("ALL %0d TESTS PASSED", tests);
        else             $display("%0d of %0d TESTS FAILED", errors, tests);
        $finish;
    end

endmodule
