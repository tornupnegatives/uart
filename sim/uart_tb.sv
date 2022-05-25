`timescale 1ns / 1ps

module uart_tb;
    logic           i_clk;
    logic           i_rst_n;

    logic [10:0]    i_config;

    logic           i_tx_valid;
    logic [8:0]     i_tx_parallel;
    logic [8:0]     o_rx_parallel;

    logic           o_tx;
    logic           i_rx;

    logic           o_tx_ready;
    logic           o_rx_error;
    logic           o_rx_valid;

    // 100 MHz clock
    always #5 i_clk = ~i_clk;
    real t_in  = 2.0;
    real t_out = 7.0;

    // Connect UART to itself
    always @(posedge i_clk) i_rx = o_tx;

    uart_top DUT(.*);

    initial begin
        $dumpfile("uart.vcd");
        $dumpvars(0, uart_tb);
    end

    initial begin
        $display("Simulation start");
        i_clk           = 0;
        i_rst_n         = 1;
        i_config        = 0;
        i_tx_valid      = 0;
        i_tx_parallel   = 0;
        i_rx            = 0;

        reset;
        repeat (5)
            send_word($urandom_range(0, 255));

        $display("Simulation finish");
        $finish;
    end

    task reset;
         $display("Resetting...");

        @(posedge i_clk)
            #t_in i_rst_n = 0;

        repeat (25) @(posedge i_clk);

        repeat (2) @(posedge i_clk)
            #t_in i_rst_n = 1;

        @(posedge i_clk)
            #t_out assert(o_rx_parallel === 'h0 &&
                          o_tx          === 'h1 &&
                          o_tx_ready    === 'h1 &&
                          o_rx_error    === 'h0 &&
                          o_rx_valid    === 'h0) else
                    $fatal(1, "ERROR: Incorrect status outputs after reset");
    endtask

    task send_word;
        input [7:0] word;
        logic [8:0] rx;

        $display("Sending x%b...", word);

        @(posedge i_clk) begin
            i_tx_parallel = word;
            #t_in i_tx_valid = 'h1;
        end

        @(posedge i_clk)
            #t_in i_tx_valid = 'h0;

        $display("Waiting for RX...");
        @(posedge o_rx_valid or posedge o_rx_error) begin
            if (o_rx_error)
                $fatal(1, "Error flag raised during RX");

            @(posedge i_clk)
                #t_out rx = o_rx_parallel;
        end

        $display("Received x%b\n", rx);
        assert(rx === word) else $fatal(1);
    endtask
endmodule