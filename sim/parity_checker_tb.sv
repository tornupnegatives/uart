`timescale 1ns/1ps

module parity_checker_tb;
    logic [7:0] i_word;
    logic       o_parity;

    parity_checker DUT(.i_word, .o_parity);

    initial begin
        $dumpfile("parity_checker.vcd");
        $dumpvars(0, parity_checker_tb);
    end

    initial begin
        $display("Simulation start");
        i_word = 8'b00000000;
        
        #105

        for (int i = 0; i < 8; i++) begin
            #1 i_word = {i_word[6:0], 1'h1};

            if ((i + 1) % 2 == 0)
                #20 assert (o_parity) else
                    $fatal(1, "Incorrect parity for %b", i_word);
            else
                #20 assert (~o_parity) else
                    $fatal(1, "Incorrect parity for %b", i_word);
        end

        $display("Simulation finish");
        $finish;
    end
endmodule