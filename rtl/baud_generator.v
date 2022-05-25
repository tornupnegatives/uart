`timescale 1ns / 1ps

///////////////////////////////////////////////////////////////////////////////
// Module Name:     Clock Divider
// Target Devices:  Xilinx Artix-7
// Description:     Baud rate generator for use in a UART environment
// Author:          Joseph Bellahcen <tornupnegatives@gmail.com>
//
// Notes:           Generates one of ten baud rates per select bits
///////////////////////////////////////////////////////////////////////////////

module baud_generator
    #(parameter FPGA_CLK = 100_000_000)
    (
        // FPGA interface
        input i_clk,
        input i_rst_n,

        // Baud rate select
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
        input [3:0] i_baud_select,
        input       i_update_baud,

        output  o_clk,
        output  o_rising_edge,
        output  o_falling_edge,
        output  o_stable
    );

    // Baud rate divisors
    integer BAUD0 = FPGA_CLK / 9600;
    integer BAUD1 = FPGA_CLK / 19200;
    integer BAUD2 = FPGA_CLK / 38400;
    integer BAUD3 = FPGA_CLK / 57600;
    integer BAUD4 = FPGA_CLK / 115200;
    integer BAUD5 = FPGA_CLK / 230400;
    integer BAUD6 = FPGA_CLK / 460800;
    integer BAUD7 = FPGA_CLK / 921600;
    integer BAUD8 = FPGA_CLK / 1000000;
    integer BAUD9 = FPGA_CLK / 1500000;

    // FSM
    localparam [1:0]
        SETUP   = 2'b01,
        RUN     = 2'b10;

    reg [1:0] r_state, r_next_state;

    // Clock divisor
    reg [9:0]   r_config, r_next_config;
    reg [31:0]  r_cdiv,   r_next_cdiv;

    // Counter
    reg [31:0] r_fast_cycle, r_next_fast;

    // Slow clock
    reg r_clk,          r_next_clk;
    reg r_rising_edge,  r_falling_edge;
    reg r_stable;

    // State machine logic
    always @(posedge i_clk) begin
        if (~i_rst_n) begin
            r_state         <= RUN;
            r_config        <= 'h0;
            r_cdiv          <= BAUD0;
            r_fast_cycle    <= 'h0;
            r_clk           <= 'h0;
        end

        else begin
            r_state         <= r_next_state;
            r_config        <= r_next_config;
            r_cdiv          <= r_next_cdiv;
            r_fast_cycle    <= r_next_fast;
            r_clk           <= r_next_clk;
        end
    end

    always @(*) begin
        // Defaults
        r_next_state    = r_state;
        r_next_config   = r_config;
        r_next_cdiv     = r_cdiv;
        r_next_fast     = r_fast_cycle;
        r_next_clk      = r_clk;
        
        r_rising_edge   = 'h0;
        r_falling_edge  = 'h0;
        r_stable        = 'h0;

        case(r_state)
            SETUP: begin
                case (r_config)
                    0:          r_next_cdiv = BAUD0;
                    1:          r_next_cdiv = BAUD1;
                    2:          r_next_cdiv = BAUD2;
                    3:          r_next_cdiv = BAUD3;
                    4:          r_next_cdiv = BAUD4;
                    5:          r_next_cdiv = BAUD5;
                    6:          r_next_cdiv = BAUD6;
                    7:          r_next_cdiv = BAUD7;
                    8:          r_next_cdiv = BAUD8;
                    9:          r_next_cdiv = BAUD9;
                    default:    r_next_cdiv = BAUD0;
                endcase

                r_next_state = RUN;
             end       

            RUN: begin    
                // Toggle slow clock when fast clock hits divisor
                if (i_update_baud) begin
                    r_next_config = i_baud_select;
                    r_next_fast     = 'h0;
                    r_next_clk      = 'h0;
                    r_next_state    = SETUP;
                end

                else if (i_rst_n) begin
                    // Toggle clock edge
                    if (r_fast_cycle == r_cdiv/2) begin
                        r_next_fast     = 'h0;
                        r_next_clk      = ~r_clk;
                        
                        r_rising_edge   = ~r_clk;
                        r_falling_edge  = r_clk;
                       
                    end

                    else begin
                        r_next_fast = r_fast_cycle + 'h1;
                        r_stable = (r_fast_cycle == r_cdiv / 4) && r_clk;
                    end
                end
            end
        endcase
    end

    // Outputs
    assign o_clk = r_clk;
    assign o_rising_edge = r_rising_edge;
    assign o_falling_edge = r_falling_edge;
    assign o_stable = r_stable;
endmodule

