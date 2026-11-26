# SMS core for Karabas Go / Mini / Mini G (ISE 14.7).
# Ф0: size of the machine alone: make sms-xst (with FM) / make sms-xst-nofm, then make sms-report.
# The upstream rtl comes from ../tools/fetch_upstream.sh (git-ignored).

ISE_SETTINGS ?= /opt/Xilinx/14.7/ISE_DS/settings64.sh

SHELL = /bin/bash
.SHELLFLAGS = -e -o pipefail -c

XIL = source $(ISE_SETTINGS) > /dev/null;

prj_src = $(shell sed -n 's/^[a-z]* work "\(.*\)"/\1/p' $(1) 2>/dev/null)

sms_%.ngc: measure/sms_%.xst measure/sms.prj $(call prj_src,measure/sms.prj)
	mkdir -p xst_$*/projnav.tmp
	$(XIL) nice -n 19 xst -intstyle ise -ifn measure/sms_$*.xst -ofn measure/xst_$*.log

sms-xst: sms_fm.ngc
sms-xst-nofm: sms_nofm.ngc

sms-report:
	@for v in fm nofm; do [ -f measure/xst_$$v.log ] || continue; echo "== $$v"; \
	grep -E "Number of Slice (Registers|LUTs)|Number of Block RAM/FIFO|Number of DSP48|Maximum Frequency" measure/xst_$$v.log; done

clean:
	rm -rf xst xst_* _xmsgs *.ngc *.ngr *.lso *.srp *.syr *.xrpt

.PHONY: sms-xst sms-xst-nofm sms-report clean
