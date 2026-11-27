#!/usr/bin/env python3
"""Makes the Go and Mini files from those of Mini G: rtl/karabas_{mini,go}_top.v from
rtl/karabas_minig_top.v, the timing part of karabas_{mini,go}.ucf from karabas_minig.ucf (their pin
part stays: the pins of core-sega), karabas_{mini,go}.prj / .xst / .ut from the Mini G ones.

The three tops share everything but the board: change the Mini G top, then run this (every
replacement must match once, else it stops). After tools/mktops.py of core-sega (the template) and
core-gameboy (Go: V_CLK inverted, no ADC).

Mini (before rev.G): MCU_SCK not on a clock pin (no BUFG, bursts at the link clock), 4 MCU_IO,
  sigma-delta audio on AUDIO_L / AUDIO_R instead of the PCM5102, FT_RESET, the ESP pins.
Go: VGA 8:8:8 with V_CLK (clk_65 inverted, karabas-go notes go-vclk-phase) instead of HDMI, the
  FT812 off the video bus (FT_OE_N = 1), no FT_CLK_OUT, no ADC (PCM1808), the MCU link on
  MCU_SPI_*, DAC_LRCK / DAC_MUTE, the floppy connector unused (its outputs 0), the SDRAM /CS hard
  wired (FLASH_CS_N = 1: the flash chip).
Both: the SAM2695 synth held in reset (MIDI_RESET_N = 0, no MIDI_CLK).
"""
import os
import re
import sys

SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
RTL = os.path.join(SRC, "rtl")


def sub(s, old, new, what):
    if s.count(old) != 1:
        sys.exit("mktops.py: %s: %d matches of %r" % (what, s.count(old), old[:70]))
    return s.replace(old, new)


def ports(s, body):
    a = s.index("module karabas_minig_top (")
    b = s.index("\n);\n", a) + 4
    return s[:a] + body + s[b:]


COMMON_PORTS_HEAD = """	input wire CLK_50MHZ,

	inout wire UART_RX,
	inout wire UART_TX,
	inout wire UART_CTS,
	inout wire ESP_RESET_N,
	inout wire ESP_BOOT_N,

	output wire [20:0] MA,
	inout wire [15:0] MD,
	output wire [1:0] MWR_N,
	output wire [1:0] MRD_N,

	output wire [1:0] SDR_BA,
	output wire [12:0] SDR_A,
	output wire SDR_CLK,
	output wire [1:0] SDR_DQM,
	output wire SDR_WE_N,
	output wire SDR_CAS_N,
	output wire SDR_RAS_N,
	inout wire [15:0] SDR_DQ,

	output wire SD_CS_N,
	output wire SD_CLK,
	output wire SD_DI,
	input wire SD_DO,
	input wire SD_DET_N,
"""

FLASH_PORTS = """	output wire FLASH_CS_N,
	input wire FLASH_DO,
	output wire FLASH_DI,
	output wire FLASH_SCK,
	output wire FLASH_WP_N,
	output wire FLASH_HOLD_N
);
"""

MINI_PORTS = "module karabas_mini_top (\n" + COMMON_PORTS_HEAD + """
	input wire [7:0] VGA_R,
	input wire [7:0] VGA_G,
	input wire [7:0] VGA_B,
	input wire VGA_HS,
	input wire VGA_VS,

	output wire [3:0] TMDS_P,
	output wire [3:0] TMDS_N,

	output wire FT_SPI_CS_N,
	output wire FT_SPI_SCK,
	input wire FT_SPI_MISO,
	output wire FT_SPI_MOSI,
	input wire FT_INT_N,
	input wire FT_CLK,
	input wire FT_DE,
	input wire FT_AUDIO,
	input wire FT_DISP,
	output wire FT_RESET,
	output wire FT_CLK_OUT,

	output wire [2:0] WA,
	output wire [1:0] WCS_N,
	output wire WRD_N,
	output wire WWR_N,
	output wire WRESET_N,
	inout wire [15:0] WD,

	output wire TAPE_OUT,
	input wire TAPE_IN,

	output wire AUDIO_L,
	output wire AUDIO_R,

	output wire ADC_CLK,
	inout wire ADC_BCK,
	inout wire ADC_LRCK,
	input wire ADC_DOUT,

	input wire MCU_CS_N,
	input wire MCU_SCK,
	inout wire MCU_MOSI,
	output wire MCU_MISO,
	inout wire [3:0] MCU_IO, // [1] INT of link v2, [2] sd2 cs_n, [3] ft cs_n

	output wire MIDI_TX,

	output wire MIDI_CLK,
	output wire MIDI_RESET_N,

""" + FLASH_PORTS

GO_PORTS = "module karabas_go_top (\n" + COMMON_PORTS_HEAD + """
	output wire [7:0] VGA_R,
	output wire [7:0] VGA_G,
	output wire [7:0] VGA_B,
	output wire VGA_HS,
	output wire VGA_VS,
	output wire V_CLK,

	output wire FT_SPI_CS_N,
	output wire FT_SPI_SCK,
	input wire FT_SPI_MISO,
	output wire FT_SPI_MOSI,
	input wire FT_INT_N,
	input wire FT_CLK,
	output wire FT_OE_N,

	output wire [2:0] WA,
	output wire [1:0] WCS_N,
	output wire WRD_N,
	output wire WWR_N,
	output wire WRESET_N,
	inout wire [15:0] WD,

	input wire FDC_INDEX,
	output wire [1:0] FDC_DRIVE,
	output wire FDC_MOTOR,
	output wire FDC_DIR,
	output wire FDC_STEP,
	output wire FDC_WDATA,
	output wire FDC_WGATE,
	input wire FDC_TR00,
	input wire FDC_WPRT,
	input wire FDC_RDATA,
	output wire FDC_SIDE_N,

	output wire TAPE_OUT,
	input wire TAPE_IN,
	output wire BEEPER,

	output wire DAC_LRCK,
	output wire DAC_DAT,
	output wire DAC_BCK,
	output wire DAC_MUTE,

	input wire MCU_CS_N,
	input wire MCU_SCK,
	inout wire MCU_MOSI,
	output wire MCU_MISO,
	input wire MCU_SPI_FT_CS_N,
	input wire MCU_SPI_SD2_CS_N,
	inout wire [1:0] MCU_SPI_IO, // [0] INT of link v2 (firmware IO1, GPIO2), [1] unused (IO0, GPIO14)

	output wire MIDI_TX,
	output wire MIDI_CLK,
	output wire MIDI_RESET_N,

""" + FLASH_PORTS

HEADER_G = (" Sega Master System / Game Gear / SG-1000 core for Karabas Mini rev.G (HDMI, PCM5102): the machine of\n"
            " SMS_MiSTer (rtl/karabas/sms_machine.vhd: system + video + work RAM) with the board glue of\n"
            " karabas-go-modules (after karabas-go-core-sega and -gameboy).\n")
BODY = " The machine of SMS_MiSTer (rtl/karabas/sms_machine.vhd) with the board glue of karabas-go-modules.\n"

MCU_SCK_G = """// MCU_SCK on a global buffer (as tsconf and the menu: on local routing the flip-flops of the SPI
// receiver had several ns of clock skew); the FT812 and SD2 get the IBUFG output (a BUFG drives no pad)
wire mcu_sck_ibufg, mcu_sck;
IBUFG ibufg_mcu_sck (.I(MCU_SCK), .O(mcu_sck_ibufg));
BUFG bufg_mcu_sck (.I(mcu_sck_ibufg), .O(mcu_sck));
"""
MCU_SCK_OLD = """// MCU_SCK is not on a clock pin before rev.G (CLOCK_DEDICATED_ROUTE = FALSE in the ucf)
wire mcu_sck = MCU_SCK, mcu_sck_ibufg = MCU_SCK;
"""

UNUSED_SYNTH = """assign ESP_RESET_N = 1'bz;
assign ESP_BOOT_N = 1'bz;
assign MIDI_CLK = 1'b0;      // the SAM2695 synth: held in reset, no use for it here
assign MIDI_RESET_N = 1'b0;
"""

FT_CLK = """// the clock of the FT812 (it must always have one): 65 / 8 = 8.125 MHz
reg [1:0] ft_div = 2'd0;
reg ft_q = 1'b0;
always @(posedge clk_65) begin
	ft_div <= ft_div + 2'd1;
	if (ft_div == 2'd3) ft_q <= ~ft_q;
end
ODDR2 oddr_ft_clk (.Q(FT_CLK_OUT), .C0(clk_65), .C1(~clk_65), .CE(1'b1), .D0(ft_q), .D1(ft_q), .R(1'b0), .S(1'b0));
"""

PCM_LRCK = "	.lrck(DAC_WS)\n"
PCM_FROM = "// DIV_BITS 3: bck 1.69 MHz, 52.9 kHz."
PCM_TO = "	.lrck(DAC_WS)\n);\n"


def common(s):
    s = sub(s, "assign ESP32_SPI_CS_N = 1'b1;\n", "", "ESP32_SPI_CS_N")
    s = sub(s, "assign MIDI_TX = 1'b1;\n", "assign MIDI_TX = 1'b1;\n" + UNUSED_SYNTH, "unused")
    s = sub(s, MCU_SCK_G, MCU_SCK_OLD, "MCU_SCK")
    return s


def mini(s):
    s = sub(s, HEADER_G,
            " Sega Master System / Game Gear / SG-1000 core for Karabas Mini before rev.G (HDMI, sigma-delta audio).\n"
            " Made by tools/mktops.py from karabas_minig_top.v (do not edit: change that one and run it): the same\n"
            " except the pins, the MCU link (MCU_SCK not on a clock pin) and the audio (AUDIO_L / AUDIO_R).\n" + BODY, "header")
    s = ports(s, MINI_PORTS)
    s = common(s)
    s = sub(s, "assign MIDI_RESET_N = 1'b0;\n", "assign MIDI_RESET_N = 1'b0;\nassign FT_RESET = 1'b1;\n", "FT_RESET")
    s = sub(s, "assign MCU_IO[5:2] = 4'bzzzz;\n", "assign MCU_IO[3:2] = 2'bzz;\n", "MCU_IO")  # INT on MCU_IO[1]
    a = s.index(PCM_FROM)
    b = s.index(PCM_TO, a) + len(PCM_TO)
    s = s[:a] + ("// no I2S DAC on this board: sigma-delta outputs into an RC filter, offset binary input\n"
                 "kg_sigma_delta_dac dac_l (.clk(mclk), .reset(areset), .din({ ~aud_l[15], aud_l[14:0] }), .dout(AUDIO_L));\n"
                 "kg_sigma_delta_dac dac_r (.clk(mclk), .reset(areset), .din({ ~aud_r[15], aud_r[14:0] }), .dout(AUDIO_R));\n") + s[b:]
    return s


def go(s):
    s = sub(s, HEADER_G,
            " Sega Master System / Game Gear / SG-1000 core for Karabas Go (VGA, PCM5102, no ADC). Made by\n"
            " tools/mktops.py from karabas_minig_top.v (do not edit: change that one and run it): the same\n"
            " except the pins, the MCU link (MCU_SCK not on a clock pin), no ADC (line in) and the video: 24 bit\n"
            " RGB to the VGA DAC with its pixel clock on V_CLK (clk_65 inverted), the FT812 off that bus\n"
            " (FT_OE_N = 1). The floppy connector is not used (its outputs 0).\n" + BODY, "header")
    s = ports(s, GO_PORTS)
    s = common(s)
    a = s.index("// the ADC (PCM1808")
    b = s.index("// the machine audio")
    s = s[:a] + "// no ADC (PCM1808) on Go: no line in\nwire [23:0] adc_l = 24'd0, adc_r = 24'd0;\n\n" + s[b:]
    s = sub(s, "assign MIDI_RESET_N = 1'b0;\n",
            "assign MIDI_RESET_N = 1'b0;\nassign FT_OE_N = 1'b1;     // the FT812 does not drive the video DAC\n"
            "assign BEEPER = 1'b0;\n"
            "assign DAC_MUTE = 1'b1;    // soft mute of the PCM5102: 1 = sound on\n\n"
            "// the floppy connector is not used: its outputs 0 (the board inverts them: high = active)\n"
            "assign FDC_DRIVE = 2'b00;\nassign FDC_MOTOR = 1'b0;\nassign FDC_DIR = 1'b0;\nassign FDC_STEP = 1'b0;\n"
            "assign FDC_WDATA = 1'b0;\nassign FDC_WGATE = 1'b0;\nassign FDC_SIDE_N = 1'b0;\n", "unused Go")
    s = sub(s, FT_CLK,
            "// the pixel clock of the VGA DAC: clk_65 inverted (the DAC takes the pixel at the rising edge of V_CLK,\n"
            "// in the middle of the data of a rising clk_65; karabas-go notes go-vclk-phase)\n"
            "ODDR2 oddr_v_clk (.Q(V_CLK), .C0(clk_65), .C1(~clk_65), .CE(1'b1), .D0(1'b0), .D1(1'b1), .R(1'b0), .S(1'b0));\n",
            "V_CLK")
    s = sub(s, "assign MCU_IO[1] = mcu_int;\nassign MCU_IO[0] = 1'bz;\nassign MCU_IO[5:2] = 4'bzzzz;\n",
            "// INT of link v2 on MCU_SPI_IO[0] (N9, the IO1 line of the firmware)\n"
            "assign MCU_SPI_IO[0] = mcu_int;\nassign MCU_SPI_IO[1] = 1'bz;\n", "MCU_IO")
    s = sub(s, "	.MCU_SPI_FT_SS(MCU_IO[3]),\n	.MCU_SPI_SD2_SS(MCU_IO[2]),\n",
            "	.MCU_SPI_FT_SS(MCU_SPI_FT_CS_N),\n	.MCU_SPI_SD2_SS(MCU_SPI_SD2_CS_N),\n", "MCU SS")
    s = sub(s, PCM_LRCK, "	.lrck(DAC_LRCK)\n", "DAC_LRCK")
    s = sub(s, "   pll_clk<0> 65.0 MHz (/10): the video out (1024 x 768 at 60 Hz), the OSD, HDMI; FT_CLK_OUT 8.125 MHz\n"
               "   pll_clk<1>, <2> 325 MHz (/2, 0 and 180 degrees): the HDMI serialiser\n",
            "   pll_clk<0> 65.0 MHz (/10): the video out (1024 x 768 at 60 Hz, VGA, V_CLK), the OSD\n"
            "   (pll_clk<1>, <2>, the HDMI serialiser of Mini / Mini G, are not used here)\n", "clocks")
    s = sub(s, "// FLASH_CS_N (T3) is the SDRAM /CS of Mini G2 (rev G: tied low on the board)\n"
               "assign FLASH_CS_N = sdr_cs_n;\n",
            "// the SDRAM /CS is hard wired on Go: sdr_cs_n is not used; FLASH_CS_N is the flash chip\n"
            "assign FLASH_CS_N = 1'b1;\n", "sdr_cs_n")
    # the HDMI part: from the audio crossing into clk_65 to the end
    a = s.index("// into clk_65 for HDMI")
    b = s.index("endmodule")
    s = s[:a] + """// ------------------------------------------------------------------ VGA

// the syncs of the overlay output go with osd_rgb
reg vga_hs = 1'b1, vga_vs = 1'b1;
always @(posedge clk_65) begin
	vga_hs <= ~osd_hs;   // 1024 x 768 at 60 Hz: negative syncs (VESA)
	vga_vs <= ~osd_vs;
end
reg [23:0] vga_rgb = 24'd0;
always @(posedge clk_65)
	vga_rgb <= osd_de ? osd_rgb : 24'd0;
assign VGA_R = vga_rgb[23:16];
assign VGA_G = vga_rgb[15:8];
assign VGA_B = vga_rgb[7:0];
assign VGA_HS = vga_hs;
assign VGA_VS = vga_vs;

""" + s[b:]
    return s


MARK = "# ------------------------------------------------------------------------------------------------------------\n# Timing constraints"


def ucf(board):
    g = open(os.path.join(SRC, "karabas_minig.ucf")).read()
    timing = g[g.index(MARK):]
    timing = sub(timing, "karabas_minig_top.v", "karabas_%s_top.v" % board, "ucf top")
    if board == "go":
        timing = sub(timing, "#   pll_clk<0> 65.0 MHz (/10): clk_65, the video out, the OSD, HDMI, FT_CLK_OUT (/8)\n"
                     "#   pll_clk<1>, <2> 325 MHz (/2, 0 and 180 degrees): the HDMI serialiser\n",
                     "#   pll_clk<0> 65.0 MHz (/10): clk_65, the video out (VGA, V_CLK), the OSD\n"
                     "#   pll_clk<1>, <2>: not used on Go\n", "ucf go clocks")
    path = os.path.join(SRC, "karabas_%s.ucf" % board)
    pins = open(path).read()
    pins = pins[:pins.index(MARK)] if MARK in pins else pins.rstrip("\n") + "\n\n"
    open(path, "w").write(pins + timing)
    print(os.path.normpath(path))


def project(board):
    p = open(os.path.join(SRC, "karabas_minig.prj")).read()
    p = sub(p, '"rtl/karabas_minig_top.v"', '"rtl/karabas_%s_top.v"' % board, "prj top")
    if board == "go":
        p = "".join(l for l in p.splitlines(True) if "/video/hdmi/" not in l and "i2s_transceiver" not in l)
    for ext, text in ((".prj", p),
                      (".xst", open(os.path.join(SRC, "karabas_minig.xst")).read().replace("karabas_minig", "karabas_" + board)),
                      (".ut", open(os.path.join(SRC, "karabas_minig.ut")).read())):
        path = os.path.join(SRC, "karabas_%s%s" % (board, ext))
        open(path, "w").write(text)
        print(os.path.normpath(path))


src = open(os.path.join(RTL, "karabas_minig_top.v")).read()
for name, f in (("karabas_mini_top.v", mini), ("karabas_go_top.v", go)):
    out = os.path.join(RTL, name)
    open(out, "w").write(f(src))
    print(os.path.normpath(out))
for board in ("mini", "go"):
    ucf(board)
    project(board)
