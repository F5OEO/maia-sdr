# axi_vcxo_ctrl — pre-built IP
SUBDIRS := axi_vcxo_ctrl
.PHONY: all clean $(SUBDIRS)
all clean: $(SUBDIRS)
$(SUBDIRS):
	$(MAKE) -C $@ $(MAKECMDGOALS)
