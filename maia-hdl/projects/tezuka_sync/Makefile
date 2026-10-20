####################################################################################
## Copyright (c) 2018 - 2023 Analog Devices, Inc.
### SPDX short identifier: BSD-1-Clause
## Auto-generated, do not modify!
####################################################################################
#make PROJECT_NAME=e310
# export PROJECT_NAME=libre && make for example

PROJECT_NAME ?= e310

export PROJECT_NAME

M_DEPS += ../../adi-hdl/library/common/ad_iobuf.v
M_DEPS += ../../adi-hdl/library/axi_ad9361/axi_ad9361_delay.tcl
M_DEPS += ip_cores
LIB_DEPS += xilinx/util_clkdiv
LIB_DEPS += axi_ad9361
LIB_DEPS += util_rfifo
LIB_DEPS += util_wfifo
LIB_DEPS += axi_dmac
LIB_DEPS += util_pack/util_cpack2
LIB_DEPS += util_pack/util_upack2

#DEST = ../../../../tezuka_fw/board/tezuka/$(PROJECT_NAME)/bitstream
DEST = /media/hp-z2-dev/Variste/Doc/prog/tezuka_fw/board/tezuka/$(PROJECT_NAME)/bitstream
include ../../adi-hdl/projects/scripts/project-xilinx.mk

build_project: $(PROJECT_NAME).xpr

ip_cores:
	$(MAKE) -C ../../ip

clean:
	bash -c "rm -rf build $(PROJECT_NAME).*"
	bash -c "rm -f *.log *.jou *.str *.xpr *.xsa"
	@echo "Local project cleaned. IP cores preserved."

install:
	bash -c "mkdir -p $(DEST) && cp -f $(PROJECT_NAME).sdk/system_top.xsa $(DEST)/$(notdir $(CURDIR)).xsa"
# FSBL will be done with embeddedsw later by buildroot 	
#	bash -c "rm -rf build"
#	bash -c "xsct create_fsbl_project.tcl $(PROJECT_NAME)"
#	bash -c "cp -f build/sdk/fsbl/Release/fsbl.elf $(DEST)/"
#	bash -c "./all_overclock.sh $(PROJECT_NAME)"
#	bash -c "cp -f build/sdk/fsbl/Release/fsbl_CPU*.elf $(DEST)/overclock/"

all: ip_cores build_project install

.PHONY: ip_cores build_project install all clean


