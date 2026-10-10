TOP ?= alu_tb
RTL := $(wildcard rtl/*.sv)
TB  := tb/$(TOP).sv

.PHONY: sim clean
sim:
	rm -rf obj_dir
	verilator --cc --exe --trace --timing --main --top-module $(TOP) $(RTL) $(TB)
	make -C obj_dir -f V$(TOP).mk CXX=g++ LINK=g++ OPT_GLOBAL=-O2
	./obj_dir/V$(TOP).exe

clean:
	rm -rf obj_dir
