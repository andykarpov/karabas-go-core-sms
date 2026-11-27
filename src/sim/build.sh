#!/bin/bash
# Builds the verilator models obj/Vsms_machine (the machine) and obj_sys/Vsim_top (the board path of the
# cartridge, sim_top.v): the VHDL of the machine (measure/sms.prj) through
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

model() { # obj top cflags sources...
	local OBJ=$1 TOP=$2 CF=$3; shift 3
	local EXE=$B/$OBJ/V$TOP
	if newer $EXE "$* sim/$GEN sim/sim_sms.cpp sim/build.sh"; then
		echo "JOB-STAGE: verilator $TOP"
		(cd $SRC && verilator -O3 --x-assign fast --x-initial fast --default-language 1364-2005 \
			-Wno-fatal -Wno-lint -Wno-style -Wno-BLKANDNBLK -Wno-MULTIDRIVEN -Wno-UNOPTFLAT -Wno-WIDTH \
			-Wno-CASEINCOMPLETE --no-timing --top-module $TOP -Mdir sim/$B/$OBJ --cc $CF \
			sim/$GEN "$@" --exe $HERE/sim_sms.cpp -o V$TOP > sim/$B/verilator_$OBJ.log 2>&1) \
			|| { grep -E '%Error' $B/verilator_$OBJ.log | head -20; exit 1; }
		echo "JOB-STAGE: c++ $TOP"
		nice -n 19 make -s -j3 -C $B/$OBJ -f V$TOP.mk OPT_FAST=-O2 > $B/make_$OBJ.log 2>&1 || { tail -30 $B/make_$OBJ.log; exit 1; }
	fi
}
# the machine alone (the ROM in the harness), the board path (loader, SDRAM controller, chip model)
model obj sms_machine "" $VLOG
model obj_sys sim_top "-CFLAGS -DSIM_SYS" $VLOG rtl/karabas/sms_loader.v rtl/karabas/sms_sdram.v sim/sdram_model.v sim/sim_top.v
echo "model ok"
