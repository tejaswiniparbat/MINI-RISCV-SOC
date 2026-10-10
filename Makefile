.RECIPEPREFIX = >
TOP ?= alu_tb
SRC := $(wildcard rtl/*.sv)

sim:
> rm -rf obj_dir
> verilator --binary --timing -Wno-fatal --top-module $(TOP) $(SRC) tb/$(TOP).sv
> ./obj_dir/V$(TOP)

clean:
> rm -rf obj_dir
