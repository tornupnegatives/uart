`timescale 1ns/1ps

module uart_tx_tb;
    logic                   i_clk;
    logic                   i_rst_n;
    logic [6:0]             i_config;
    logic [8:0]             i_tx_parallel;
    logic                   i_tx_valid;
    logic                   i_uart_clk;
    logic                   i_uart_clk_rising_edge;
    logic                   i_uart_clk_falling_edge;
    logic                   i_tx;
    logic                   o_tx;
    logic                   o_ready;

    logic                   r_sample;

    // 100 MHz clock
    always #5 i_clk = ~i_clk;
    real t_in  = 2.0;
    real t_out = 0.0;

    baud_generator BD(
        .i_clk,
        .i_rst_n,
        .o_clk(i_uart_clk),
        .o_rising_edge(i_uart_clk_rising_edge),
        .o_falling_edge(i_uart_clk_falling_edge),
        .o_stable(r_sample)
    );

    uart_tx DUT(.*);

    initial begin
        $dumpfile("uart_tx.vcd");
        $dumpvars(0, uart_tx_tb);
    end

    initial begin
        $display("Simulation start");
        i_clk           = 0;
        i_rst_n         = 1;
        i_config        = 0;
        i_tx_parallel   = 0;
        i_tx_valid      = 0;
        i_tx            = 0;

        reset;

        // Two stop bits, parity check, 9-bit word
        configure(6'b11_1001);
        repeat (5)
            test_tx($urandom_range(0, 511));

        // Two stop bits, no parity check, 8-bit word
        configure(6'b10_1000);
        repeat (5)
            test_tx($urandom_range(0, 255));

        // One stop bit, no parity check, 7-bit word
        configure(6'b00_1000);
        repeat (5)
            test_tx($urandom_range(0, 127));

        // One stop bit, parity check, 6-bit word
        configure(6'b00_1000);
        repeat (5)
            test_tx($urandom_range(0, 63));

        // Two stop bit, parity check, 5-bit word
        configure(6'b11_0110);
        repeat (5)
            test_tx($urandom_range(0, 31));

        $display("Simulation finish");
        $finish;
    end

    task reset;
        $display("Resetting...");

        @(posedge i_clk)
            #t_in i_rst_n = 0;

        repeat (16) @(posedge i_clk);

        @(posedge i_clk)
            #t_in i_rst_n = 1;

        @(posedge i_clk);

        @(posedge i_clk)
            #t_out assert(o_ready === 'h1) else
                    $fatal(1, "ERROR: Failed to enter READY state after reset");
    endtask

    task configure;
        input [5:0] value;

        $display("Configuring...");
        $display("Stop bits:\t%d", value[5] ? 2 : 1);
        $display("Parity bit:\t\t%d", value[4]);
        $display("Word size:\t\t%d\n", value[3:0]);
        
        @(posedge i_clk) begin
            #t_in i_config = {value, 1'h1};
        end

        @(posedge i_clk) begin
            #t_in i_config = {value, 1'h0};
        end
    endtask

    task test_tx;
        input [8:0] data;
        logic [8:0] rx;

        $display("Transmitting x%x", data);

        rx = 'h0;

        @(posedge i_clk) begin
            i_tx_parallel = data;
            #t_in i_tx_valid = 'h1;
        end

        // Start bit
        @(posedge r_sample) begin
            #t_in i_tx_valid = 'h0;

            assert(o_tx === 'h0) else
            $fatal(1, "Could not detect start bit");
        end

        // Data
        for (int i = 0; i < i_config[4:1]; i++)
            @(posedge r_sample)
                rx[i] = o_tx;

        // Parity
        if (i_config[5])
            @(posedge r_sample)
                assert(o_tx === ($countones(data) % 2 == 0)) else
                $fatal(1, "Incorrect parity bit");

        // Stop
        repeat (i_config[6] + 1)
            @(posedge r_sample)
                assert(o_tx === 'h1) else
                $fatal(1, "Could not detect stop bit");

        // Wait for ready
        $display("Waiting for ready...");
        @(posedge i_uart_clk_falling_edge)  // Last falling edge
            @(negedge i_uart_clk_falling_edge)
                repeat (2) @(posedge i_clk);
        assert(o_tx === 'h1 && o_ready === 'h1) else
        $fatal(1, "Failed to enter ready state");

        $display("Received x%x\n", rx);
        assert(rx === data) else
        $fatal(1);
    endtask
endmodule
