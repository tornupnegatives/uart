`timescale 1ns / 1ps

///////////////////////////////////////////////////////////////////////////////
// Module Name:     UART Top
// Target Devices:  Xilinx Artix-7
// Description:     Configurable UART module with synchronized inputs
// Author:          Joseph Bellahcen <tornupnegatives@gmail.com>
///////////////////////////////////////////////////////////////////////////////

module uart_top
    (
        // FPGA interface
        input i_clk,
        input i_rst_n,

        // Configuration interface
        // ┌───────────────┬─────────────┬─────────────────────┬────────────┬──────────────┐
        // │    10...7     │      6      │         5           │   4...1    │      0       │
        // ├───────────────┼─────────────┼─────────────────────┼────────────┼──────────────┤
        // │ BAUD SELECT   │ N STOP BITS │ PARITY CHECK ENABLE │ WORD SIZE  │ STORE CONFIG │
        // │ Default: 0000 │ Default: 1  │ Default: 1          │ Default: 8 │              │
        // └───────────────┴─────────────┴─────────────────────┴────────────┴──────────────┘

        // Baud Select
        // ┌─────────────┬────────────────┐
        // │ Select Bits │ Baud Rate (HZ) │
        // ├─────────────┼────────────────┤
        // │        0000 │           9600 │
        // │        0001 │          19200 │
        // │        0010 │          38400 │
        // │        0011 │          57600 │
        // │        0100 │         115200 │
        // │        0101 │         230400 │
        // │        0110 │         460800 │
        // │        0111 │         921600 │
        // │        1000 │        1000000 │
        // │        1001 │        1500000 │
        // └─────────────┴────────────────┘
        input [10:0] i_config,

        // Parallel communication
        input         i_tx_valid,
        input   [8:0] i_tx_parallel,
        output  [8:0] o_rx_parallel,

        // UART
        input   i_rx,
        output  o_tx,

        // Status registers
        output o_ready,
        output o_rx_error,
        output o_rx_valid
    );

    // Input synchronizers
    reg [1:0] r_config_sync;
    reg [1:0] r_tx_valid_sync;
    reg [1:0] r_rx_sync;

    wire w_enable_rx;
    wire w_enable_tx;
    wire w_ready_rx;
    wire w_ready_tx;

    baud_generator BD(
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_baud_select(i_config[10:7]),
        .i_update_baud(r_config_sync[1]),
        //.o_clk,
        .o_rising_edge(w_enable_tx),
        //.o_falling_edge,
        .o_stable(w_enable_rx)
    );

    uart_tx UTX(
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_config({i_config[6:1], r_config_sync[1]}),
        .i_tx_parallel(i_tx_parallel),
        .i_tx_valid(r_tx_valid_sync[1]),
        .i_uart_clk_enable(w_enable_tx),
        .o_tx(o_tx),
        .o_ready(w_ready_tx)
    );

    uart_rx URX(
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_config({i_config[6:1], r_config_sync[1]}),
        .o_rx_parallel(o_rx_parallel),
        .o_rx_valid(o_rx_valid),
        .i_uart_clk_enable(w_enable_rx),
        .i_rx(r_rx_sync[1]),
        .o_ready(w_ready_rx),
        .o_error(o_rx_error)
    );

    always @(posedge i_clk) begin
        if (~i_rst_n) begin
            r_config_sync   <= 'h0;
            r_tx_valid_sync <= 'h0;
            r_rx_sync       <= 'h1;
        end

        else begin
            r_config_sync   <= {r_config_sync[0], i_config[0]};
            r_tx_valid_sync <= {r_tx_valid_sync[0], i_tx_valid};
            r_rx_sync       <= {r_rx_sync[0], i_rx};
        end
    end

    assign o_ready = w_ready_tx && w_ready_rx;
endmodule
