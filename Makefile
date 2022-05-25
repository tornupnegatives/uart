COMPILER=iverilog
CFLAGS=-g2012 -Wall
SIM=vvp

test-parity-checker:
	$(COMPILER) $(CFLAGS) -o test_parity_checker rtl/parity_checker.v sim/parity_checker_tb.sv
	$(SIM) ./test_parity_checker
	rm -f test_parity_checker
	
clean:
	rm -f *.vcd