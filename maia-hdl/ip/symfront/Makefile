VIVADO := vivado -mode batch -source
IP_CORE_VERSION := $(shell PYTHONPATH="../../:${PYTHONPATH}" python3 -m maia_hdl.maia_sdr_version)

all: symfront

symfront:
	mkdir -p symfront
	PYTHONPATH="../../:${PYTHONPATH}" python3 -m maia_hdl.symfront generate -t v symfront/symfront.v
	cd symfront && IP_CORE_VERSION=$(IP_CORE_VERSION) $(VIVADO) ../package_ip.tcl

clean:
	rm -rf symfront

.PHONY: all clean symfront
