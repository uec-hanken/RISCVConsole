#########################################################################################
# pre-process RSA into a single blackbox file
#########################################################################################
RSA_DIR ?= $(optvsrc_dir)/rsa/

# name of output pre-processed verilog file
RSA_PREPROC_VERILOG = rsa.preprocessed.v

.PHONY: rsa $(RSA_PREPROC_VERILOG)
rsa:  $(RSA_PREPROC_VERILOG)

#########################################################################################
# includes and vsrcs
#########################################################################################
RSA_PKGS = 

RSA_VSRCS = $(RSA_DIR)/RSA_getNumBit.v\
            $(RSA_DIR)/RSA_comp.v\
            $(RSA_DIR)/RSA_addsub.v

RSA_WRAPPER = \
	$(RSA_DIR)/RSA_ModExp.v

RSA_ALL_VSRCS = $(RSA_PKGS) $(RSA_VSRCS) $(RSA_WRAPPER)

#########################################################################################
# pre-process using verilator
#########################################################################################

lookup_dirs = $(shell find -L $(vsrc_dir) -name target -prune -o -type d -print 2> /dev/null | grep '.*/\($(1)\)$$')
RSA_INC_DIR_NAMES ?= include
RSA_INC_DIRS ?= $(foreach dir_name,$(RSA_INC_DIR_NAMES),$(call lookup_dirs,$(dir_name)))

# these flags are specific to Chipyard
RSA_EXTRA_PREPROC_DEFINES ?=
RSA_PREPROC_DEFINES ?= \
	WT_DCACHE \
	DISABLE_TRACER \
	SRAM_NO_INIT \
	VERILATOR \
	$(RSA_EXTRA_PREPROC_DEFINES)

$(RSA_PREPROC_VERILOG): $(RSA_ALL_VSRCS)
	mkdir -p $(dir $(RSA_PREPROC_VERILOG))
	$(foreach def,$(RSA_PREPROC_DEFINES),echo "\`define $(def)" >> def.v; )
	$(foreach def,$(RSA_PREPROC_DEFINES),echo "\`undef $(def)" >> undef.v; )
	cat def.v $(RSA_ALL_VSRCS) undef.v > combined.v
	sed -i '/l15.tmp.h/d' combined.v
	sed -i '/define.tmp.h/d' combined.v
	$(PREPROC_SCRIPT) combined.v $@ $(RSA_INC_DIRS)
	rm -rf combined.v def.v undef.v

