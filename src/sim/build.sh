#!/bin/bash
# Builds the verilator model obj/Vsms_machine: the VHDL of the machine (measure/sms.prj) through
# ghdl --synth --out=verilog (FM on), the Verilog of rtl/sv (jt89, MC8123, SEGASYS1, parts) and the
# harness sim_sms.cpp. Output in src/sim/build/. Rebuilds only when a source is newer.
set -e
cd "$(dirname "$0")"
SRC=..
B=build
HERE=$PWD
mkdir -p $B/ghdl
VHDL=$(cd $SRC && sed -n 's/^vhdl work "\(.*\)"/\1/p' measure/sms.prj | tr '\n' ' ')
VLOG=$(cd $SRC && sed -n 's/^verilog work "\(rtl\/.*\)"/\1/p' measure/sms.prj | tr '\n' ' ')
GO="--std=08 -frelaxed -fsynopsys -Wno-shared -Wno-hide -Wno-binding --workdir=sim/$B/ghdl"
newer() { [ ! -e "$1" ] || [ -n "$(cd $SRC && find $2 -newer sim/$1 2>/dev/null)" ]; }

GEN=$B/sms_machine_ghdl.v
if newer $GEN "$VHDL sim/build.sh"; then
	echo "JOB-STAGE: ghdl"
	rm -rf $B/ghdl/*
	(cd $SRC && ghdl --synth --out=verilog $GO $VHDL -e sms_machine 2> sim/$B/ghdl.log) > $GEN.tmp
	grep -q error $B/ghdl.log && { grep error $B/ghdl.log | head; exit 1; }
	# escaped names of ghdl (\reg , also glued to a prefix: u0_\reg ) -> plain names reg_e, u0_reg_e
	perl -pe 's/\\([A-Za-z_][A-Za-z0-9_]*) /$1_e/g' $GEN.tmp > $GEN
	rm $GEN.tmp
fi

EXE=$B/obj/Vsms_machine
if newer $EXE "$VLOG sim/$GEN sim/sim_sms.cpp sim/build.sh"; then
	echo "JOB-STAGE: verilator"
	(cd $SRC && verilator -O3 --x-assign fast --x-initial fast --default-language 1364-2005 \
		-Wno-fatal -Wno-lint -Wno-style -Wno-BLKANDNBLK -Wno-MULTIDRIVEN -Wno-UNOPTFLAT -Wno-WIDTH \
		-Wno-CASEINCOMPLETE --no-timing --top-module sms_machine -Mdir sim/$B/obj --cc \
		sim/$GEN $VLOG --exe $HERE/sim_sms.cpp -o Vsms_machine > sim/$B/verilator.log 2>&1) \
		|| { grep -E '%Error' $B/verilator.log | head -20; exit 1; }
	echo "JOB-STAGE: c++"
	nice -n 19 make -s -j3 -C $B/obj -f Vsms_machine.mk OPT_FAST=-O2 > $B/make.log 2>&1 || { tail -30 $B/make.log; exit 1; }
fi
echo "model ok"
