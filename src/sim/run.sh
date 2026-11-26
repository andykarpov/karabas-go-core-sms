#!/bin/bash
# The checks (~1 min + the model build): the SMS machine (sms_machine, VHDL through ghdl, Verilator)
# runs the own test ROM sim/tests/vdptest.sms (vdptest.asm: mode 4 colour bars, checker, a sprite,
# a PSG tone) for 20 frames; the last frame must equal vdptest-reference.ppm pixel for pixel.
set -e
cd "$(dirname "$0")/.."
sim/build.sh
echo "JOB-STAGE: vdptest"
sim/build/obj/Vsms_machine --rom sim/tests/vdptest.sms --frames 20 --ppm sim/build/vdptest \
	--expect-ppm sim/tests/vdptest-reference.ppm | tail -2
echo "all checks passed"
