#!/bin/sh
# Fetch the Sega Master System upstream sources into upstream/ (git-ignored), pinned commits.
#  - MiSTer-devel/SMS_MiSTer: SMS / Game Gear / SG-1000 / SC-3000, VHDL rtl (port of Ben's Papilio core),
#    its mist/ top on EP3C25 + SDRAM = the base here
#  - nand2mario/smstang (Tang Console) and Schmiddty/SMSTangNano20k (GPL-3.0, Tang Nano 20K): the same core
#    translated to Verilog (2025 snapshot), donors only (opll.v)
set -eu
cd "$(dirname "$0")/.."
mkdir -p upstream
get() { # dir url commit
	[ -d "upstream/$1/.git" ] || git clone -q "$2" "upstream/$1"
	git -C "upstream/$1" fetch -q origin
	git -C "upstream/$1" checkout -q "$3"
	echo "$1 $(git -C "upstream/$1" rev-parse --short HEAD)"
}
get sms_mister  https://github.com/MiSTer-devel/SMS_MiSTer.git      bb77fbd8deca57e384d276e0ddb0454ee0242d32
get smstang     https://github.com/nand2mario/smstang.git           3d36b96bec75b572a9c8f2d15f2573d7a24a9dc1
get smstang20k  https://github.com/Schmiddty/SMSTangNano20k.git     5684d309f91f5a518b2cd6becfa6e327d35c135a
echo "upstream ok"
