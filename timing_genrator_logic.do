vlib work
vlog master.sv timing_generator_logic_tb.sv
vsim work.timing_generator_logic_tb
log /timing_generator_logic_tb/clk
log /timing_generator_logic_tb/rst
log /timing_generator_logic_tb/dut/countQuart
log /timing_generator_logic_tb/dut/countPulse
run -all
