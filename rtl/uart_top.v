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

        // Control interface
        input         i_request_tx,
        input         i_ws_n,
        input         i_rs_n,
        input [3:0]   i_addr,

        // Data busses
        input   [8:0] i_data,
        output  [8:0] o_data,

        // UART
        input   i_rx,
        output  o_tx,

        // Status registers
        output o_ready,
        output o_rx_error,
        output o_rx_valid
    );

    // Debug registers (read-only)
    wire [5:0]   w_uart_tx_state,        w_uart_rx_state;
    wire [7:0]   w_whoami;

    // Control registers (read/write)
    reg [6:0]   r_uart_tx_config,       r_next_uart_tx_config;
    reg [6:0]   r_uart_rx_config,       r_next_uart_rx_config;
    reg [4:0]   r_baud_speed,           r_next_baud_speed;

    // Output control
    reg  [8:0] r_data, r_next_data;
    wire [8:0] w_uart_rx;

    // Stable inputs
    wire w_request_tx;
    wire w_ws_n, w_rs_n;
    wire w_rx;

    sync S0(.i_clk(i_clk), .i_sig(i_request_tx), .o_stable(w_request_tx));
    sync S1(.i_clk(i_clk), .i_sig(i_ws_n), .o_stable(w_ws_n));
    sync S2(.i_clk(i_clk), .i_sig(i_rs_n), .o_stable(w_rs_n));
    sync S3(.i_clk(i_clk), .i_sig(i_rx), .o_stable(w_rx));

    // Clock enables from baud generators
    wire w_enable_rx;
    wire w_enable_tx;

    baud_generator BD(
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_baud_select(r_baud_speed[4:1]),
        .i_update_baud(r_baud_speed[0]),
        //.o_clk,
        .o_rising_edge(w_enable_tx),
        //.o_falling_edge,
        .o_stable(w_enable_rx)
    );

    uart_tx UTX(
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_config(r_uart_tx_config),
        .i_tx_parallel(i_data),
        .i_tx_valid(w_request_tx),
        .i_uart_clk_enable(w_enable_tx),
        .o_tx(o_tx),
        .o_ready(o_ready)
    );

    uart_rx URX(
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_config(r_uart_rx_config),
        .o_rx_parallel(w_uart_rx),
        .o_rx_valid(o_rx_valid),
        .i_uart_clk_enable(w_enable_rx),
        .i_rx(w_rx),
        //.o_ready,
        .o_error(o_rx_error)
    );

    // FSM
    localparam [5:0]
        READY       = 6'b000001,
        REQUEST_TX  = 6'b000010,
        UART_TXRX   = 6'b000100,
        READ_REG    = 6'b001000,
        WRITE_REG   = 6'b010000,
        CONFIG      = 6'b100000;

    reg [5:0] r_state, r_next_state;

    always @(posedge i_clk) begin
        if (~i_rst_n) begin
            r_state          <= READY;
            r_uart_tx_config <= 7'b10_1000_0;
            r_uart_rx_config <= 7'b10_1000_0;
            r_baud_speed     <= 5'b0000_0;
            r_data           <= 'h0;
        end

        else begin
            r_state          <= r_next_state;
            r_uart_tx_config <= r_next_uart_tx_config;
            r_uart_rx_config <= r_next_uart_rx_config;
            r_baud_speed     <= r_next_baud_speed;
            r_data           <= r_next_data;
        end
    end

    always @(*) begin
        r_next_state          = r_state;
        r_next_uart_tx_config = r_uart_tx_config;
        r_next_uart_rx_config = r_uart_rx_config;
        r_next_baud_speed     = r_baud_speed;
        r_next_data           = r_data;

        case (r_state)
            READY: begin
                if (w_request_tx)
                    r_next_state = REQUEST_TX;
                
                else if (~i_rs_n)
                    r_next_state = READ_REG;

                else if (~i_ws_n)
                    r_next_state = WRITE_REG;
            end

            REQUEST_TX: begin
                r_next_data = 'h0;
                r_next_state = o_rx_valid ? REQUEST_TX : UART_TXRX;
            end

            UART_TXRX: begin
                if (o_rx_valid) begin
                    r_next_data = w_uart_rx;
                    r_next_state = READY;
                end
            end

            READ_REG: begin
                case (i_addr)
                    0:  r_next_data = 'h0;
                    1:  r_next_data = 'hff;
                    2:  r_next_data = w_uart_tx_state;
                    3:  r_next_data = w_uart_rx_state;
                    4:  r_next_data = w_whoami;
                    5:  r_next_data = r_uart_tx_config;
                    6:  r_next_data = r_uart_rx_config;
                    7:  r_next_data = r_baud_speed;
                endcase

                r_next_state = READY;
            end

            WRITE_REG: begin
                case (i_addr)
                    5:  r_next_uart_tx_config   = {i_data[6:1], 1'h1};
                    6:  r_next_uart_rx_config   = {i_data[6:1], 1'h1};
                    7:  r_next_baud_speed       = {i_data[4:1], 1'h1};
                endcase

                r_next_state = CONFIG;
            end

            CONFIG: begin
                r_next_uart_tx_config = {r_uart_tx_config[6:1], 1'h0};
                r_next_uart_rx_config = {r_uart_rx_config[6:1], 1'h0};
                r_next_baud_speed     = {r_baud_speed[4:1], 1'h0};

                r_next_state = READY;
            end
        endcase
    end

    // Debug registers
    assign w_whoami = 8'hB9;
    assign w_uart_tx_state = UTX.r_state;
    assign w_uart_rx_state = URX.r_state;

    assign o_data = r_data;
endmodule