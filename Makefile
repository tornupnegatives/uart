COMPILER=iverilog
CFLAGS=-g2012 -Wall
SIM=vvp

test-parity-checker:
	$(COMPILER) $(CFLAGS) -o test_parity_checker rtl/parity_checker.v sim/parity_checker_tb.sv
	$(SIM) ./test_parity_checker
	rm -f test_parity_checker

test-baud-generator:
	$(COMPILER) $(CFLAGS) -o test_baud_generator rtl/baud_generator.v sim/baud_generator_tb.sv
	$(SIM) ./test_baud_generator
	rm -f test_baud_generator

test-uart-tx:
	$(COMPILER) $(CFLAGS) -o test_uart_tx rtl/parity_checker.v rtl/baud_generator.v rtl/uart_tx.v sim/uart_tx_tb.sv
	$(SIM) ./test_uart_tx
	rm -f test_uart_tx
	
clean:
	rm -f *.vcd