`timescale 1ns/1ps

// Runs firmware/i2c_demo.hex on the SoC against a behavioural I2C slave (address 0x50).
module soc_i2c_tb;

    logic        clk = 1'b0;
    logic        rst = 1'b1;
    logic [15:0] gpio_out;
    logic        uart_tx;
    logic        i2c_scl_o, i2c_sda_o, slave_sda;
    wire         sda_bus = i2c_sda_o & slave_sda;      // open-drain wired-AND
    int errors = 0, tests = 0;

    soc_top #(.INIT_FILE("firmware/i2c_demo.hex")) dut (
        .clk(clk), .rst(rst), .gpio_in(16'h0000), .gpio_out(gpio_out),
        .uart_tx(uart_tx), .uart_rx(1'b1),
        .spi_sclk(), .spi_mosi(), .spi_miso(1'b0), .spi_cs_n(),
        .i2c_scl_o(i2c_scl_o), .i2c_sda_o(i2c_sda_o), .i2c_sda_i(sda_bus)
    );

    i2c_slave_model #(.ADDR(7'h50)) slave (.scl(i2c_scl_o), .sda_in(sda_bus), .sda_out(slave_sda));

    always #5 clk = ~clk;

    task automatic check(input string name, input logic [31:0] got, input logic [31:0] exp);
        tests++;
        if (got !== exp) begin errors++; $display("FAIL %-22s got=%h expected=%h", name, got, exp); end
        else $display("PASS %-22s = %h", name, got);
    endtask

    initial begin
        repeat (3) @(posedge clk);
        @(negedge clk) rst = 1'b0;
        repeat (12000) @(posedge clk);
        #1;

        check("firmware done",        dut.u_core.u_dmem.mem[519], 32'hC0DE600D);
        check("addr+W ACKed",         dut.u_core.u_dmem.mem[512], 32'd0);
        check("register ptr ACKed",   dut.u_core.u_dmem.mem[513], 32'd0);
        check("data 5A ACKed",        dut.u_core.u_dmem.mem[514], 32'd0);
        check("data 6B ACKed",        dut.u_core.u_dmem.mem[515], 32'd0);
        check("slave mem[8] = 5A",    32'(slave.mem[8]), 32'h5A);
        check("slave mem[9] = 6B",    32'(slave.mem[9]), 32'h6B);
        check("read back byte 0",     dut.u_core.u_dmem.mem[516], 32'h5A);
        check("read back byte 1",     dut.u_core.u_dmem.mem[517], 32'h6B);
        check("wrong addr NACKed",    dut.u_core.u_dmem.mem[518], 32'd1);
        check("STARTs seen",          32'(slave.n_start), 32'd4);
        check("STOPs seen",           32'(slave.n_stop), 32'd3);
        check("bus idle: SCL",        32'(i2c_scl_o), 32'd1);
        check("bus idle: SDA",        32'(sda_bus), 32'd1);

        if (errors == 0) $display("ALL %0d TESTS PASSED", tests);
        else             $display("%0d of %0d TESTS FAILED", errors, tests);
        $finish;
    end

endmodule
