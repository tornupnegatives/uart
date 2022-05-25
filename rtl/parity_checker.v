`timescale 1ns/1ps

///////////////////////////////////////////////////////////////////////////////
// Module Name:     Parity Checker
//
// Description:     Simple combinational circuit to count 1s in an 8-bit word
//
// Author:          Joseph Bellahcen <tornupnegatives@gmail.com>
///////////////////////////////////////////////////////////////////////////////

module parity_checker
    (
        // FPGA interface
        input [7:0] i_word,
        output reg  o_parity
    );

    integer idx;
    reg [3:0] count;        // Max: 8

    always @(*) begin
        count = 'h0;

        for (idx = 0; idx < 8; idx = idx + 1)
            count = count + i_word[idx];

        o_parity = (count % 2 == 0);
    end
endmodule
