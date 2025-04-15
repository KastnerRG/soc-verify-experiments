# Makefile for compiling, elaborating, and simulating with Xilinx tools

#VLOG_SRCS := $(shell cat sources.txt)
#VHDL_SRCS := $(shell cat sources_vhdl.txt)

WORK_DIR := run/work
TB := testbench
SNAPSHOT := $(TB)
TCL := ../xsim_cfg.tcl

all: xsim

# Ensure the work directories exist
$(WORK_DIR):
	mkdir -p $(WORK_DIR)

comp: $(WORK_DIR)
	cd $(WORK_DIR) && xvlog -f ../sources.txt && xvhdl -f ../sources_vhdl.txt && xvlog -f ../sources_tb.txt
	touch $@

elab: comp
	cd $(WORK_DIR) && xelab $(TB) --snapshot $(SNAPSHOT) -log elaborate.log --debug typical
	touch $@

xsim: elab
	cd $(WORK_DIR) && xsim $(SNAPSHOT) --tclbatch $(TCL)
	touch $@

clean:
	rm -rf $(WORK_DIR)*