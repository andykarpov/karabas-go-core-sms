#!/bin/bash
# The XST source list of a board: karabas_<board>.prj = the machine (measure/sms.prj: the SMS_MiSTer
# rtl, the RAMs, sms_machine), the board glue of rtl/karabas, the modules of karabas-go-modules
# (tools/board_modules.prj), the top; then tools/mktops.py makes the Go / Mini files from the Mini G ones.
set -e
cd "$(dirname "$0")/.."
GLUE="sms_sdram sms_loader sms_kbd sms_sk1100 sms_fb"
for b in minig; do
	{ cat measure/sms.prj
	  for g in $GLUE; do echo "verilog work \"rtl/karabas/$g.v\""; done
	  echo 'vhdl work "rtl/karabas/i2s_transceiver.vhd"'
	  cat tools/board_modules.prj
	  echo "verilog work \"rtl/karabas_${b}_top.v\""
	} > karabas_$b.prj
done
python3 tools/mktops.py > /dev/null
