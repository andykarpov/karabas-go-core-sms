# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

A Sega Master System / Game Gear / SG-1000 / SC-3000 core for the Karabas Go, Mini and Mini G boards: Xilinx Spartan-6 XC6SLX25, ISE 14.7 (XST).

Status: started 2026-11-27, Ф0 next. Public repo github.com/andykarpov/karabas-go-core-sms. Docs, in Russian: `docs/PLAN.md` (research, decisions, architecture, phases), `docs/BACKLOG.md`. Follow the phases; record a changed decision in PLAN.md.

Base: [MiSTer-devel/SMS_MiSTer](https://github.com/MiSTer-devel/SMS_MiSTer) `rtl/` (VHDL-93 mostly: T80, VDP, VM2413 FM, jt89 PSG, mappers, EEPROM), its `mist/` top (EP3C25 + SDRAM) as the closest example of a small board. The Verilog translations nand2mario/smstang and Schmiddty/SMSTangNano20k are donors only. Get them with `tools/fetch_upstream.sh` (git-ignored, pinned). Keep the upstream headers; mark changed lines `-- karabas:` / `// karabas:`. The core is GPL v3 (`LICENSE`).

All file work goes through the firmware (OSD, `FL` / `F` items, burst): no loader or soft CPU in the core.

Pieces from our cores: `../karabas-go-core-sega` (Sega glue: `gen_ctrl`, keyboard as pads, SRAM frame buffer 1024x768, `.sav` via `kg_bk_ram`), `../karabas-go-core-gameboy` and `../karabas-go-core-wonderswan` (cartridge in SDRAM, triple-buffered SRAM frame buffer, saves, `tools/vhdl93.py`, `tools/sv2v.sh`, `tools/mktops.py`, verilator + ghdl sim harness).

## Rules of the core

The rules of the other karabas-go cores apply: one clock with enables (no gated / derived clocks), standard video timing with syncs always present, `FT_CLK_OUT` about 8 MHz on Mini / Mini G, Go `FDC_*` outputs 0 when unused, Mini / Mini G drive T3 (`FLASH_CS_N`), OSD switch index = item position unless `"index"`, an OSD value shows 10 characters at most, FL slots 0..7 only, Verilog-2001 for XST (`sv2v` for SV), VHDL-93 for XST, imported code marked `karabas:`.

- No game ROMs and no Sega BIOS in the repo or the `.kg`; free test ROMs (homebrew, test suites) only under `src/sim/tests` if their licence allows.
- `karabas-go-modules` is shared with other sessions: change it only in a git worktree, PR there, then move the submodule.
- Before a step that needs the board or the HDMI capture, tell the user; capture frames only after a yes; ask before a firmware flash.
- One branch per phase of `docs/PLAN.md`, one PR at its end.
- The base set of every board top: audio peaks to the MCU (`audio_peaks`, MATRIX_CMD), the ADC (PCM1808) in the mix, FT_CLK_OUT, MIDI_TX (idle here), tape in / out + monitor where it makes sense (SC-3000 has a tape port). Go / Mini files: edit the Mini G top, then `src/tools/mktops.py`.
- Heavy builds: Mini G only while working on one feature, all boards for a release; map with cost table 2 first.

## Memory

The Claude Code memory of this repo is shared with all karabas-go repos: `~/.claude/projects/<this project>/memory` is a symlink to `../karabas-go-notes` (private repo `andykarpov/karabas-go-notes`, `link.sh` there makes the links). Its `MEMORY.md` is split by repo; commit and push it after every memory change.
