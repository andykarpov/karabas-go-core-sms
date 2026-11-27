# Sega Master System / Game Gear / SG-1000 core for Karabas Go / Mini / Mini G

[Русская версия](README.ru.md)

Sega Master System, Game Gear, SG-1000 and SC-3000 for the Karabas Go board family (Xilinx Spartan-6 XC6SLX25). A port of the [MiSTer SMS core](https://github.com/MiSTer-devel/SMS_MiSTer) (itself a port of Ben's Papilio core), with the board glue of [karabas-go-modules](https://github.com/andykarpov/karabas-go-modules).

| Board | Core file | Video | Sound |
|---|---|---|---|
| Karabas Go | `sms.kg` | VGA | I2S DAC (PCM5102) |
| Karabas Mini | `sms.kg` | HDMI | HDMI, analog output (sigma-delta), line in |
| Karabas Mini G | `sms.kg` | HDMI | HDMI, I2S DAC, line in |

The core file is in `src/`. It needs the firmware **v26112702** or newer (the file loader sends the file extension, which selects the system). No Sega BIOS and no game images are included: the core starts a cartridge directly. Put your own `.sms` / `.gg` / `.sg` / `.sc` files on the SD card in `/sms`. Free homebrew to try it with: the games of [haroldo-ok](https://github.com/haroldo-ok) for the Master System (MIT: [Juno First](https://github.com/haroldo-ok/juno-first-sms), [Star Frag 3D](https://github.com/haroldo-ok/star-frag-3d-sms), [Scorched](https://github.com/haroldo-ok/scorched-sms), [Sub Rescue](https://github.com/haroldo-ok/sub-rescue)) and the SG-1000 games of [Mojon Twins](https://github.com/mojontwins/loves_the_sg1000) (LGPL-3.0).

Status: checked on Mini G. The Go and Mini builds have not been run on a board yet.

## Features

- **Systems, by the extension of the file:** `.sms` (or any other) Master System, `.gg` Game Gear (its 160 x 144 screen and 4096-colour palette), `.sg` SG-1000 (the TMS9918 palette), `.sc` SC-3000 (+ the SK-1100 keyboard on the USB keyboard).
- **Cartridges:** ROMs up to 4 MB in the SDRAM, the mappers of the MiSTer core with its automatic detection (Sega, Codemasters, Korean, MSX-style and more), copier headers of 512 bytes skipped.
- **Sound:** the PSG (SN76489) and the FM unit (YM2413, OSD item); stereo over HDMI and on the DAC / analog output. The line input of the board (and its MIDI synth) is mixed in (Mini G, Mini).
- **Video:** the picture scaled by a whole number in both directions into 1024 x 768 at 60 Hz: 256 x 192 x 4 = the whole screen, 224 / 240 lines x 3, Game Gear x 5. A frame buffer in the SRAM shows the last complete frame (the machine runs at its own 59.9 / 50 Hz), so frames are never torn.
- **Saves:** the cartridge RAM (and the EEPROM of the Game Gear cartridges that have one) is kept in `/sms/saves/<game>.sav` on the SD card (32 KB for every game, as MiSTer), written a second after the game changes it.

Not done: the Sega BIOS, System E, the Master System Evolution flash, light gun / paddle / multitap, Mega Drive pads, Gear-to-Gear, save states, cheats.

## Getting started

1. Copy `sms.kg` (one file for Go, Mini and Mini G) to the root of the SD card.
2. Put your games in `/sms` on the SD card.
3. Choose Master System in the core menu, choose a game in the file browser (**Menu+Esc** opens it again). Next time the core starts the last game again.

"Menu" is the Windows key of the keyboard.

## OSD menu

| Item | Values | Hotkey |
|---|---|---|
| Region | Export / Japan (the region of the console) | |
| Video | NTSC / PAL | |
| FM sound | On / Off | |
| Border | Off / On (the border of the VDP around the picture) | |
| Swap joys | Off / On | |
| Left column | BG / Black (the left column a game masks: the backdrop colour or black) | |
| Sprites | Standard / All (All: more than 4 sprites per line in the SG-1000 modes, less flicker; as MiSTer) | |
| Reset | resets the machine | F12 |

## Controls

| Master System | Keyboard (pad 1) | Keyboard (pad 2) | USB pad |
|---|---|---|---|
| D-pad | arrows | I J K L | d-pad |
| Button 1 | Z | U | A |
| Button 2 | X or C | O or P | B or C |
| Pause (Game Gear: Start) | Enter | M | Start |

On the SC-3000 the keyboard is the SK-1100 keyboard instead (the arrows, Enter and the letters as on it; Alt = GRAPH, Caps Lock = ENG DIER'S, F1 = FUNC, Esc = BREAK, Home = CLR HOME, Insert / Delete = INS DEL).

## Building

Clone with `--recursive` (the `modules` submodule) and get the upstream sources with `tools/fetch_upstream.sh` (only needed to compare; the imported RTL is in `src/rtl/sms`). ISE 14.7: `cd src && make` for all boards or `make minig` for one. The Mini and Go tops (and the timing part of their ucf) are made from the Mini G top by `src/tools/mktops.py`; the source lists by `src/tools/mkprj.sh`.

Checks: `src/sim/run.sh` (a few minutes): the frame buffer (`tb_fb`, iverilog, three sizes pixel for pixel), then the machine in Verilator (the VHDL through `ghdl --synth`) running the own test ROMs of `src/sim/tests` (`vdptest` for the Master System and the Game Gear, `sgtest` for the SG-1000, `savetest` for the cartridge RAM), also through the board path (loader, SDRAM controller, SDRAM model). The plan and the design notes are in [docs/PLAN.md](docs/PLAN.md) (Russian).

## Licence

GPL-3.0 (see [LICENSE](LICENSE)). The MiSTer SMS core is GPL (no licence file; its forks are GPL-3.0).

Sega, Master System, Game Gear and SG-1000 are trademarks of Sega. This project is not affiliated with Sega.
