`timescale 1ns / 1ps

module uart_tb;
    logic           i_clk;
    logic           i_rst_n;

    logic           i_request_tx;
    logic           i_ws_n;
    logic           i_rs_n;
    logic [3:0]     i_addr;

    logic [8:0]     i_data;
    logic [8:0]     o_data;

    logic           i_rx;
    logic           o_tx;

    logic           o_ready;
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
        i_clk           = 'h0;
        i_rst_n         = 'h1;
        i_request_tx    = 'h0;
        i_ws_n          = 'h1;
        i_rs_n          = 'h1;
        i_addr          = 'h0;
        i_data          = 'h0;
        i_rx            = 'h0;

        reset;
        repeat (5)
            send_word($urandom_range(0, 255));

        @(posedge i_clk) begin
            i_addr = 'h7;
            i_data = 'h9;
            #t_in i_ws_n = 'h0;
        end

        @(posedge i_clk)
            #t_in i_ws_n = 'h1;
        
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
            #t_out assert(o_data        === 'h0 &&
                          o_tx          === 'h1 &&
                          o_ready       === 'h1 &&
                          o_rx_error    === 'h0 &&
                          o_rx_valid    === 'h0) else
                    $fatal(1, "ERROR: Incorrect status outputs after reset");
    endtask

    task send_word;
        input [7:0] word;
        logic [8:0] rx;

        $display("Sending x%b...", word);

        @(posedge i_clk) begin
            i_data = word;
            #t_in i_request_tx = 'h1;
        end

        @(posedge i_clk)
            #t_in i_request_tx = 'h0;

        $display("Waiting for RX...");
        @(posedge o_rx_valid or posedge o_rx_error) begin
            @(posedge i_clk) begin
                #t_out rx = o_data;

                if (o_rx_error)
                    $fatal(1, "Error flag raised during RX");
            end
        end

        $display("Received x%b\n", rx);
        assert(rx === word) else $fatal(1);
    endtask
endmodule