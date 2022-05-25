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
        output      o_parity
    );

    integer idx;
    reg [3:0] r_count;        // Max: 8
    reg       r_parity;

    always @(*) begin
        r_count  = 'h0;
        r_parity = 'h0;

        for (idx = 0; idx < 8; idx = idx + 1)
            r_count = r_count + i_word[idx];

        r_parity = (r_count % 2 == 0);
    end
    
    assign o_parity = r_parity;
endmodule
