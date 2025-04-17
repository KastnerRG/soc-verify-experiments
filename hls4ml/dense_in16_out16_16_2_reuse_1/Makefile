# Makefile for compiling, elaborating, and simulating with Xilinx tools

#VLOG_SRCS := $(shell cat sources.txt)
#VHDL_SRCS := $(shell cat sources_vhdl.txt)

B ?= 8
I ?= 8
O ?= 8
VALID_PROB = 50
READY_PROB = 50

RUN_DIR = run
WORK_DIR := run/work
DATA_DIR = $(WORK_DIR)/data
FULL_DATA_DIR = $(abspath $(DATA_DIR))
C_SOURCE = ../../c/sim.c
TB_MODULE := top_tb
XSIM_CFG := ../xsim_cfg.tcl

XSC_FLAGS = --gcc_compile_options -DSIM --gcc_compile_options -DDIR=$(FULL_DATA_DIR)/ --gcc_compile_options -I$(FULL_DATA_DIR)
XVLOG_FLAGS = -sv -d "DIR=$(FULL_DATA_DIR)/" -d "R=$(B)" -d "C=$(I)" -d "VALID_PROB=$(VALID_PROB)" -d "READY_PROB=$(READY_PROB)" -i $(abspath $(RUN_DIR))
XELAB_FLAGS = --snapshot $(TB_MODULE) -log elaborate.log --debug typical -sv_lib dpi
XSIM_FLAGS = --tclbatch $(XSIM_CFG)

all: xsim

# Ensure the work directories exist
$(WORK_DIR):
	mkdir -p $(WORK_DIR)

$(DATA_DIR): | $(WORK_DIR)
	mkdir -p $(DATA_DIR)

$(DATA_DIR)/x.bin: $(DATA_DIR)
	python run/golden_hls4ml.py --B $(B) --I $(I) --O $(O) --DIR $(FULL_DATA_DIR)

# Compile C source
c: $(WORK_DIR) $(DATA_DIR)/x.bin
	cd $(WORK_DIR) && xsc $(C_SOURCE) $(XSC_FLAGS)

comp: c
	cd $(WORK_DIR) && xvlog -f ../sources.txt $(XVLOG_FLAGS) && xvhdl -f ../sources_vhdl.txt
	touch $@

elab: comp
	cd $(WORK_DIR) && xelab $(TB_MODULE) $(XELAB_FLAGS) 
	touch $@

xsim: elab
	cd $(WORK_DIR) && xsim $(TB_MODULE) $(XSIM_FLAGS) 
	touch $@

clean:
	rm -rf $(WORK_DIR)*
	-rm comp elab xsim

# not just clean the sim files, but also the hls4ml project files
deepclean: clean
	-rm -rf *_prj/
	-rm -rf *_result/
	-rm -rf rtl/hdl/*