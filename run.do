vlog master_tb.sv
vsim -voptargs="+acc" work.master_tb
add wave -position insertpoint\
sim:/master_tb/dut/*
run -all
