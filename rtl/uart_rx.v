`timescale 1ns / 1ps

///////////////////////////////////////////////////////////////////////////////
// Module Name:     UART RX
// Target Devices:  Xilinx Artix-7
// Description:     Configurable UART RX module
// Author:          Joseph Bellahcen <tornupnegatives@gmail.com>
///////////////////////////////////////////////////////////////////////////////

module uart_rx
    (
        // FPGA interface
        input               i_clk,
        input               i_rst_n,

        // Configuration interface
        // ┌──────────────┬─────────────────────┬─────────────┬──────────────┐
        // │      6       │          5          │    4...1    │      0       │
        // ├──────────────┼─────────────────────┼─────────────┼──────────────┤
        // │ N STOP BITS  │ PARITY CHECK ENABLE │ WORD SIZE   │ STORE CONFIG │
        // │ Default: 0   │ Default: 1          │ Default: 8  │              │
        // │ 0=1, 1=2     │                     │ Range [5,9] │              │
        // └──────────────┴─────────────────────┴─────────────┴──────────────┘
        input [6:0]             i_config,

        // Parallel communication bus
        output [8:0]            o_rx_parallel,
        output                  o_rx_valid,

        // UART interface
        input                   i_uart_clk_enable,
        input                   i_rx,

        output                  o_ready,
        output                  o_error
    );

    // FSM
    localparam [6:0]
        READY       = 7'b0000001,
        RX_START    = 7'b0000010,
        RX_DATA     = 7'b0000100,
        RX_PARITY   = 7'b0001000,
        RX_STOP     = 7'b0010000,
        ERROR       = 7'b0100000,
        DATA_VALID  = 7'b1000000;

    reg [6:0] r_state, r_next_state;

    // Internal RX register
    reg [3:0] r_idx,         r_next_idx;
    reg [8:0] r_rx_parallel, r_next_rx_parallel;

    // Configuration
    reg [3:0]   r_word_size,        r_next_word_size;
    reg         r_parity_enable,    r_next_parity_enable;
    reg         r_n_stop_bits,      r_next_n_stop_bits;

    // Parity checker
    wire w_parity;
    parity_checker PC(.i_word(r_rx_parallel), .o_parity(w_parity));
    defparam PC.WORD_SIZE = 9;

    // Status registers
    reg r_ready,    r_next_ready;
    reg r_error,    r_next_error;
    reg r_rx_valid, r_next_rx_valid;

    always @(posedge i_clk) begin
        if (~i_rst_n) begin
            r_state             <= READY;

            r_idx               <= 'h0;
            r_rx_parallel       <= 'h0;

            r_word_size         <= 'h8;
            r_parity_enable     <= 'h1;
            r_n_stop_bits       <= 'h0;

            r_ready             <= 'h0;
            r_error             <= 'h0;
            r_rx_valid          <= 'h0;
        end

        else begin
            r_state             <= r_next_state;

            r_idx               <= r_next_idx;
            r_rx_parallel       <= r_next_rx_parallel;
            
            r_word_size         <= r_next_word_size;
            r_parity_enable     <= r_parity_enable;
            r_n_stop_bits       <= r_n_stop_bits;

            r_ready             <= r_next_ready;
            r_error             <= r_next_error;
            r_rx_valid          <= r_next_rx_valid;
        end 
    end

    always @(*) begin
        r_next_state            = r_state;

        r_next_idx              = r_idx;
        r_next_rx_parallel      = r_rx_parallel;

        r_next_word_size        = r_word_size;
        r_next_parity_enable    = r_parity_enable;
        r_next_n_stop_bits      = r_n_stop_bits;

        r_next_ready            = r_ready;
        r_next_error            = r_error;
        r_next_rx_valid         = r_rx_valid;

        case (r_state)
            READY: begin
                r_next_ready = i_rst_n;
                r_next_error = 'h0;

                if (i_rst_n) begin
                    if (~i_rx)
                        r_next_state = i_uart_clk_enable ? RX_DATA: RX_START;

                    else if (i_config[0]) begin
                        r_next_parity_enable    = i_config[5];
                        r_next_n_stop_bits      = i_config[6];

                        // Ensure word size in range [5,9]
                        if (i_config[4:1] < 5)
                            r_next_word_size = 4'h5;
                        else if (i_config[4:1] > 9)
                            r_next_word_size = 4'h9;
                        else
                            r_next_word_size = i_config[4:1];

                        r_next_state = READY;
                    end
                end
            end

            RX_START: begin
                // Prepare RX register and report error if timing mismatch
                if (i_uart_clk_enable) begin
                    r_next_idx = 'h0;
                    r_next_rx_parallel = 'h0;
                    r_next_rx_valid = 'h0;

                    r_next_state = i_rx ? ERROR : RX_DATA;
                end
            end

            RX_DATA: begin
                if (i_uart_clk_enable) begin
                    //$display("Reading data bit[%d]: %d", r_idx, i_rx);
                    r_next_idx = r_idx + 1;
                    r_next_rx_parallel[r_idx] = i_rx;

                    if (r_idx == r_word_size - 1)
                        r_next_state = RX_PARITY;
                end
            end

            RX_PARITY: begin
                if (i_uart_clk_enable) begin
                    if (i_rx == w_parity) begin
                        r_next_idx = 1;
                        r_next_state = RX_STOP;
                    end

                    else
                        r_next_state = ERROR;
                end
            end

            RX_STOP: begin
                if (i_uart_clk_enable) begin
                    if (i_rx == 'h1) begin
                        r_next_idx = r_idx - 1;
                        r_next_state = (r_n_stop_bits && r_idx) ? RX_STOP : DATA_VALID;
                    end

                    else
                        r_next_state = ERROR;
                end
            end

            ERROR: begin
                r_next_error = 'h1;
                r_next_state = READY;
            end

            DATA_VALID: begin
                r_next_rx_valid = 'h1;
                r_next_state = READY;
            end
        endcase
    end

    assign o_rx_parallel = r_rx_parallel;
    assign o_rx_valid = r_rx_valid;
    assign o_ready = r_ready;
    assign o_error = r_error;
endmodule