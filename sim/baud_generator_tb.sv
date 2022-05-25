`timescale 1ns/1ps

module baud_generator_tb;
    logic           i_clk;
    logic           i_rst_n;
    logic [3:0]     i_baud_select;
    logic           i_update_baud;
    logic           o_clk;
    logic           o_rising_edge;
    logic           o_falling_edge;
    logic           o_stable;

    baud_generator DUT(.*);

    // 100 MHz clock
    //defparam DUT.FPGA_CLK = 100_000_000;
    localparam FPGA_CLK = 100_000_000;
    always #5 i_clk = ~i_clk;

    real t_in  = 2.0;
    real t_out = 0.0;

    initial begin
        $dumpfile("baud_generator.vcd");
        $dumpvars(0, baud_generator_tb);
    end

    initial begin
        $display("Simulation start");
        i_clk         = 0;
        i_rst_n       = 0;
        i_baud_select = 0;
        i_update_baud = 0;

        reset;

        for (int i = 0; i < 10; i++)
            test_clk(i);

        $display("Simulation finish");
        $finish;
    end

    task reset;
        $display("Resetting...");

        repeat (16) @(posedge i_clk)
            #t_in i_rst_n = 0;

        @(posedge i_clk)
            #t_in i_rst_n = 1;

        @(posedge i_clk)
            #t_out assert(~o_clk && ~o_rising_edge && ~o_falling_edge && ~o_stable) else
                        $fatal(1, "ERROR: Failed to reset");
    endtask

    task test_clk;
        input [3:0] baud_rate;

        static integer baud_div[9:0];
        baud_div[0] = FPGA_CLK / 9600;
        baud_div[1] = FPGA_CLK / 19200;
        baud_div[2] = FPGA_CLK / 38400;
        baud_div[3] = FPGA_CLK / 57600;
        baud_div[4] = FPGA_CLK / 115200;
        baud_div[5] = FPGA_CLK / 230400;
        baud_div[6] = FPGA_CLK / 460800;
        baud_div[7] = FPGA_CLK / 921600;
        baud_div[8] = FPGA_CLK / 1000000;
        baud_div[9] = FPGA_CLK / 1500000;

        $display("Running clock at %d Hz", FPGA_CLK / baud_div[baud_rate]);

        // Configure baud rate
        @(posedge i_clk) begin
            i_baud_select = baud_rate;
            #t_in i_update_baud = 'h1;
        end

        repeat (2) @(posedge i_clk)
            #t_in i_update_baud = 'h0;

        // Allow for passage of first low clock
        if (~o_clk) begin
            $display("Waiting for active clock edge...");
            @(posedge o_clk);
        end

        for (int i = 0; i < baud_div[baud_rate] * 2; i++) begin
            @(posedge i_clk) begin
                case(i)
                    0: begin
                        #t_out assert(o_rising_edge && o_clk && ~o_falling_edge && ~o_stable) else
                        $fatal(1, "ERROR: Rising edge failure");
                    end

                    baud_div[baud_rate] / 4: begin
                        #t_out assert(~o_rising_edge && ~o_falling_edge && o_stable && o_clk) else
                        $fatal(1, "ERROR: Stable edge failure");
                    end

                    baud_div[baud_rate] / 2: begin
                        #t_out assert(~o_rising_edge && o_falling_edge && ~o_stable && o_clk) else
                        $fatal(1, "ERROR: Falling edge failure");
                    end
                endcase
            end
        end
    endtask
endmodule