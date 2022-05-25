`timescale 1ns/1ps

module uart_tx
    (
        // FPGA interface
        input                   i_clk,
        input                   i_rst_n,

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
        input [8:0]             i_tx_parallel,
        input                   i_tx_valid,

        // UART interface
        input                   i_uart_clk_enable,
        input                   i_tx,
        output                  o_tx,

        output                  o_ready
    );

    // FSM
    localparam [5:0]
        READY           = 6'b000001,
        BUILD_PACKET    = 6'b000010,
        TX_START        = 6'b000100,
        TX_DATA         = 6'b001000,
        TX_PARITY       = 6'b010000,
        TX_STOP         = 6'b100000;
    
    reg [5:0] r_state, r_next_state;

    // Configuration
    reg [3:0]   r_word_size,        r_next_word_size;
    reg         r_parity_enable,    r_next_parity_enable;
    reg         r_n_stop_bits,      r_next_n_stop_bits;

    // Device registers
    reg [8:0]   r_tx_parallel,      r_next_tx_parallel;
    reg         r_ready,            r_next_ready;

    // UART registers
    reg [3:0]   r_idx,              r_next_idx;
    reg         r_tx,               r_next_tx;

    // Parity checker
    wire w_parity;
    parity_checker PC (.i_word(r_tx_parallel), .o_parity(w_parity));
    defparam PC.WORD_SIZE = 9;

    // Slow clock
    reg [3:0] r_slow_count, r_next_slow_count;
    
    // Loop variable for input parsing
    integer i;

    always @(posedge i_clk) begin
        if (~i_rst_n) begin
            r_state         <= READY;

            r_word_size     <= 'h8;
            r_parity_enable <= 'h1;
            r_n_stop_bits   <= 'h0;

            r_tx_parallel   <= 'h0;
            r_ready         <= 'h0;

            r_idx           <= 'h0;
            r_tx            <= 'h1;
            
        end

        else begin
            r_state         <= r_next_state;

            r_word_size     <= r_next_word_size;
            r_parity_enable <= r_next_parity_enable;
            r_n_stop_bits   <= r_next_n_stop_bits;

            r_tx_parallel   <= r_next_tx_parallel;
            r_ready         <= r_next_ready;

            r_idx           <= r_next_idx;
            r_tx            <= r_next_tx;
            
        end
    end

    always @(*) begin
        r_next_state            = r_state;

        r_next_word_size        = r_word_size;
        r_next_parity_enable    = r_parity_enable;
        r_next_n_stop_bits      = r_n_stop_bits;

        r_next_tx_parallel      = r_tx_parallel;
        r_next_ready            = r_ready;

        r_next_idx              = r_idx;
        r_next_tx               = r_tx;
        
        case (r_state)
            READY: begin
                r_next_ready = i_rst_n;

                if (i_rst_n) begin
                    if (i_tx_valid) begin
                        r_next_tx_parallel  = 0;

                        // Only store word_size number of bits
                        for (i = 0; i < 9; i = i + 1)
                            r_next_tx_parallel[i] = (i < r_word_size) ? i_tx_parallel[i] : 0;

                        r_next_ready        = 'h0;
                        r_next_state        = BUILD_PACKET;
                    end

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

            // ┌───────────┬─────────────┬───────────────────────┬─────────────┐
            // │ START BIT │    DATA     │ PARITY BIT (optional) │  STOP BIT   │
            // ├───────────┼─────────────┼───────────────────────┼─────────────┤
            // │         1 │ 5-9 bits    │ Optional: 0 or 1      │ 'b1 or 'b11 │
            // └───────────┴─────────────┴───────────────────────┴─────────────┘
            BUILD_PACKET: begin
                r_next_idx = 0;
                r_next_state = TX_START;
            end

            TX_START: begin
                if (i_uart_clk_enable) begin
                    r_next_tx = 'h0;
                    r_next_state = TX_DATA;
                end
            end

            TX_DATA: begin
                //  change so that it only transmits ONCE per uart clock
                if (i_uart_clk_enable) begin
                    r_next_tx = r_tx_parallel[r_idx];
                    r_next_idx = r_idx + 1;

                    if (r_idx == r_word_size - 1) begin
                        r_next_idx = 'h1;
                        r_next_state = r_parity_enable ? TX_PARITY : TX_STOP;
                    end
                end 
            end

            TX_PARITY: begin
                if (i_uart_clk_enable) begin
                    r_next_tx = w_parity;
                    r_next_state = TX_STOP;
                end
            end

            TX_STOP: begin
                if (i_uart_clk_enable) begin
                    r_next_tx = 'h1;
                    r_next_idx = r_idx - 1;

                    r_next_state = (r_n_stop_bits && r_idx) ? TX_STOP : READY;
                end
            end
        endcase
    end

    assign o_ready = r_ready;
    assign o_tx = r_tx;
endmodule
