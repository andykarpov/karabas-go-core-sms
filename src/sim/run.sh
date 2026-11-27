#!/bin/bash
# The checks (~4 min + the model builds):
#  - sms_fb (iverilog, tb_fb.v): 256 x 192 (x 4), 256 x 224 (x 3), 160 x 144 (x 5) pixel for pixel;
#  - the SMS machine (sms_machine: VHDL through ghdl, Verilator) runs the own test ROM
#    sim/tests/vdptest.sms (vdptest.asm: mode 4 colour bars, checker, a sprite, a PSG tone) for 20
#    frames, the ROM in the harness and then through the board path (sim_top.v: sms_loader,
#    sms_sdram, the SDRAM chip model); the last frame must equal vdptest-reference.ppm;
#  - the Game Gear build vdptest.gg (the 160 x 144 window, the 12-bit palette) and the SG-1000 ROM
#    sgtest.sg (sgtest.asm: TMS9918 Graphics I, the TMS palette) against their references;
#  - savetest.sms (savetest.asm: counts its starts in the cartridge RAM) shows red (count 1).
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
echo "JOB-STAGE: Game Gear, SG-1000"
sim/build/obj/Vsms_machine --rom sim/tests/vdptest.gg --gg --frames 20 --ppm sim/build/vdptest_gg \
	--expect-ppm sim/tests/vdptest_gg-reference.ppm | tail -1
sim/build/obj/Vsms_machine --rom sim/tests/sgtest.sg --sg --frames 20 --ppm sim/build/sgtest \
	--expect-ppm sim/tests/sgtest-reference.ppm | tail -1
sim/build/obj_sys/Vsim_top --rom sim/tests/vdptest.gg --gg --frames 20 --ppm sim/build/vdptest_gg_sys \
	--expect-ppm sim/tests/vdptest_gg-reference.ppm | tail -1
echo "JOB-STAGE: savetest"
sim/build/obj/Vsms_machine --rom sim/tests/savetest.sms --frames 4 --ppm sim/build/savetest | tail -1
python3 -c "
import sys
d = open('sim/build/savetest.ppm', 'rb').read().split(b'\\n', 3)[3]
ok = all(d[i:i + 3] == bytes([255, 0, 0]) for i in range(0, len(d), 3))
print('savetest: red' if ok else 'FAIL: savetest not red'); sys.exit(0 if ok else 1)"
echo "all checks passed"
