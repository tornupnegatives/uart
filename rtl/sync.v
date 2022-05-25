`timescale 1ns / 1ps

///////////////////////////////////////////////////////////////////////////////
// Module Name:     Sync
// Description:     Simple input synchronizer
// Author:          Joseph Bellahcen <tornupnegatives@gmail.com>
///////////////////////////////////////////////////////////////////////////////

module sync
    (
        input   i_clk,
        input   i_rst_n,
        input   i_sig,
        output  o_stable
    );

    reg [1:0] r_buffer;

    always @(posedge i_clk) begin
        if (~i_rst_n)
            r_buffer <= 'h0;
        else
            r_buffer <= {r_buffer[0], i_sig};
    end

    assign o_stable = r_buffer[1];
endmodule