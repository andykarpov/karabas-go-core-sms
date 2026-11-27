#!/bin/bash
# The checks (~4 min + the model builds):
#  - sms_fb (iverilog, tb_fb.v): 256 x 192 (x 4), 256 x 224 (x 3), 160 x 144 (x 5) pixel for pixel;
#  - the SMS machine (sms_machine: VHDL through ghdl, Verilator) runs the own test ROM
#    sim/tests/vdptest.sms (vdptest.asm: mode 4 colour bars, checker, a sprite, a PSG tone) for 20
#    frames, the ROM in the harness and then through the board path (sim_top.v: sms_loader,
#    sms_sdram, the SDRAM chip model); the last frame must equal vdptest-reference.ppm.
set -e
cd "$(dirname "$0")/.."
mkdir -p sim/build
echo "JOB-STAGE: tb_fb"
(cd sim && iverilog -o build/tb_fb tb_fb.v ../rtl/karabas/sms_fb.v ../../modules/rtl/mem/kg_sdpram.v)
for a in "" "+h=224" "+w=160 +h=144"; do
	(cd sim && vvp -n build/tb_fb $a | grep -E '^(tb_fb|PASS|FAIL)' | tr '\n' ' '; echo)
	(cd sim && vvp -n build/tb_fb $a | grep -q '^PASS') || { echo "FAIL: tb_fb $a"; exit 1; }
done
sim/build.sh
echo "JOB-STAGE: vdptest"
sim/build/obj/Vsms_machine --rom sim/tests/vdptest.sms --frames 20 --ppm sim/build/vdptest \
	--expect-ppm sim/tests/vdptest-reference.ppm | tail -1
echo "JOB-STAGE: vdptest board path"
sim/build/obj_sys/Vsim_top --rom sim/tests/vdptest.sms --frames 20 --ppm sim/build/vdptest_sys \
	--expect-ppm sim/tests/vdptest-reference.ppm | tail -1
echo "all checks passed"
