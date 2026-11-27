# SMS core for Karabas Go / Mini / Mini G (ISE 14.7).
#   make minig          the Mini G bitstream and sms.kg (make minig-report: size, timing)
#   make sms-xst / sms-xst-nofm, make sms-report: the size of the machine alone (Ф0)
# The source lists: tools/mkprj.sh (measure/sms.prj by hand, karabas_<board>.prj from it, in git).

ISE_SETTINGS ?= /opt/Xilinx/14.7/ISE_DS/settings64.sh

SHELL = /bin/bash
.SHELLFLAGS = -e -o pipefail -c

XIL = source $(ISE_SETTINGS) > /dev/null;

prj_src = $(shell sed -n 's/^[a-z]* work "\(.*\)"/\1/p' $(1) 2>/dev/null)

PART = xc6slx25-ftg256-2
BOARDS = minig go mini
KG = sms.kg
JSON = core.json

# map / par options (cost table 2 by default, the rule of all the cores)
MAP_T_minig ?= 2
MAP_T_go ?= 2
MAP_T_mini ?= 2
MAP = -logic_opt off -ol high -xe n -xt 3 -register_duplication off -r 4 -global_opt off -mt 2 -detail -ir off -pr b -lc auto -power off
PAR = -ol high -xe c -mt 4

INCLUDES = $(wildcard ../modules/rtl/mcu/*.vh)

all: $(BOARDS)

define board
SRC_$(1) := $$(call prj_src,karabas_$(1).prj)

karabas_$(1).ngc: karabas_$(1).prj karabas_$(1).xst $$(SRC_$(1)) $(INCLUDES)
	mkdir -p xst/projnav.tmp
	$(XIL) nice -n 19 xst -intstyle ise -ifn karabas_$(1).xst -ofn karabas_$(1).syr

karabas_$(1).bin: karabas_$(1).ngc karabas_$(1).ucf karabas_$(1).ut
	$(XIL) ngdbuild -intstyle ise -dd _ngo -nt timestamp -uc karabas_$(1).ucf -p $(PART) karabas_$(1).ngc karabas_$(1).ngd
	$(XIL) nice -n 19 map -intstyle ise -p $(PART) -w $(MAP) -t $(MAP_T_$(1)) -o karabas_$(1)_map.ncd karabas_$(1).ngd karabas_$(1).pcf
	$(XIL) nice -n 19 par -w -intstyle ise $(PAR) karabas_$(1)_map.ncd karabas_$(1).ncd karabas_$(1).pcf
	$(XIL) trce -intstyle ise -v 3 -s 2 -n 3 -fastpaths -xml karabas_$(1).twx karabas_$(1).ncd -o karabas_$(1).twr karabas_$(1).pcf -ucf karabas_$(1).ucf
	$(XIL) bitgen -intstyle ise -f karabas_$(1).ut karabas_$(1).ncd

kg_$(1).stamp: karabas_$(1).bin $(JSON)
	python3 tools/check_osd.py $(JSON)
	python3 make_core.py $(JSON) $(KG) --boards $(1)
	touch $$@

$(1): kg_$(1).stamp
$(1)-xst: karabas_$(1).ngc
$(1)-impl: karabas_$(1).bin
$(1)-core: kg_$(1).stamp
$(1)-report:
	@grep -E "Number of (Slice LUTs|occupied Slices|RAMB16BWERs|RAMB8BWERs):" karabas_$(1)_map.mrp
	@grep -E "constraints? (was|were) met|constraints? not met|Timing Score" karabas_$(1).par | sort -u
endef

$(foreach b,$(BOARDS),$(eval $(call board,$(b))))

sms_%.ngc: measure/sms_%.xst measure/sms.prj $(call prj_src,measure/sms.prj)
	mkdir -p xst_$*/projnav.tmp
	$(XIL) nice -n 19 xst -intstyle ise -ifn measure/sms_$*.xst -ofn measure/xst_$*.log

sms-xst: sms_fm.ngc
sms-xst-nofm: sms_nofm.ngc

sms-report:
	@for v in fm nofm; do [ -f measure/xst_$$v.log ] || continue; echo "== $$v"; \
	grep -E "Number of Slice (Registers|LUTs)|Number of Block RAM/FIFO|Number of DSP48|Maximum Frequency" measure/xst_$$v.log; done

clean:
	rm -rf xst xst_* _xmsgs _ngo xlnx_auto_0_xdb *.ngc *.ngr *.ngd *.ncd *.pcf *.lso *.srp *.syr *.bld *.mrp *.map \
		*.par *.pad *.twr *.twx *.xrpt *.unroutes *.drc *.bgn *.bit *_pad.csv *_pad.txt *.ptwx *.xpi *.ngm kg_*.stamp

.PHONY: all sms-xst sms-xst-nofm sms-report clean $(BOARDS) $(BOARDS:=-xst) $(BOARDS:=-impl) $(BOARDS:=-core) $(BOARDS:=-report)
