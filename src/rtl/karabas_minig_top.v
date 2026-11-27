`timescale 1ns / 1ps
`default_nettype wire

/*
 Sega Master System / Game Gear / SG-1000 core for Karabas Mini rev.G (HDMI, PCM5102): the machine of
 SMS_MiSTer (rtl/karabas/sms_machine.vhd: system + video + work RAM) with the board glue of
 karabas-go-modules (after karabas-go-core-sega and -gameboy).

 Clocks: one PLL, VCO 650 MHz (50 * 13):
   pll_clk<5> MCLK 54.17 MHz (/12): the machine (MiSTer 53.69: 0.9 % fast), its SDRAM controller, the
              mcu link, the loader, the pads, the frame buffer writes and the SRAM, the audio
   pll_clk<3> 54.17 MHz (/12, 330 degrees = -1.54 ns): SDR_CLK through an ODDR2: the chip a little ahead
   pll_clk<0> 65.0 MHz (/10): the video out (1024 x 768 at 60 Hz), the OSD, HDMI; FT_CLK_OUT 8.125 MHz
   pll_clk<1>, <2> 325 MHz (/2, 0 and 180 degrees): the HDMI serialiser
 clk_65 is crossed with synchronisers, a toggle handshake and the line buffer of sms_fb (TIG).

 Memory: the cartridge ROM (up to 4 MB) in the SDRAM (sms_sdram: the controller of SMS_MiSTer, one
 access per CPU cycle); work RAM and VRAM in block RAM; the cartridge RAM (32 KB) in block RAM for
 now (the .sav: Ф2); the SRAM holds the frame buffers of sms_fb (x 4 = 1024 x 768 for 256 x 192).

 The cartridge: the file of the core (type fileloader: .sms, .gg, .sg, .sc in the sms folder) through
 the file loader of kg_mcu2 into the SDRAM (sms_loader); the machine is held in reset while a file
 comes and until the first one is in.

 Sound: the PSG (+ FM YM2413) of the machine, signed 16 bits, + the ADC (PCM1808: the line in and the
 MIDI synth SAM2695 of the board, half scale) -> PCM5102, HDMI; the peaks of the mix to the mcu
 (audio_peaks: the level meters). The base set of the board otherwise: FT_CLK_OUT 8.125 MHz,
 MIDI_TX idle, TAPE_OUT 0 (the tape of the SC-3000: later).

 Soft switches (core.json osd order):
   0 Region (Export / Japan)   1 Video (NTSC / PAL)   2 FM sound (On / Off)   3 Border (Off / On)
   4 Swap joysticks   5 Reset
*/

module karabas_minig_top (
	input wire CLK_50MHZ,

	inout wire UART_RX,
	inout wire UART_TX,
	inout wire UART_CTS,

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
	output wire FT_CLK_OUT,

	output wire [2:0] WA,
	output wire [1:0] WCS_N,
	output wire WRD_N,
	output wire WWR_N,
	output wire WRESET_N,
	inout wire [15:0] WD,

	output wire TAPE_OUT,
	input wire TAPE_IN,

	output wire DAC_BCK,
	output wire DAC_WS,
	output wire DAC_DAT,

	output wire ADC_CLK,
	inout wire ADC_BCK,
	inout wire ADC_LRCK,
	input wire ADC_DOUT,

	input wire MCU_CS_N,
	input wire MCU_SCK,
	inout wire MCU_MOSI,
	output wire MCU_MISO,
	inout wire [5:0] MCU_IO, // [0] burst cs_n, [1] burst ready, [2] sd2 cs_n, [3] ft cs_n

	output wire MIDI_TX,

	output wire ESP32_SPI_CS_N,
	input wire ESP32_PCM_BCK,
	input wire ESP32_PCM_RLCK,
	input wire ESP32_PCM_DAT,

	output wire FLASH_CS_N,
	input wire FLASH_DO,
	output wire FLASH_DI,
	output wire FLASH_SCK,
	output wire FLASH_WP_N,
	output wire FLASH_HOLD_N
);

// ------------------------------------------------------------------ unused

assign WA = 3'b000;
assign WCS_N = 2'b11;
assign WRD_N = 1'b1;
assign WWR_N = 1'b1;
assign WRESET_N = 1'b1;
assign WD = 16'bz;

assign TAPE_OUT = 1'b0;
assign ESP32_SPI_CS_N = 1'b1;
assign UART_RX = 1'bz;
assign UART_TX = 1'bz;
assign UART_CTS = 1'bz;
assign MIDI_TX = 1'b1;

assign FLASH_DI = 1'b1;
assign FLASH_SCK = 1'b0;
assign FLASH_WP_N = 1'b1;
assign FLASH_HOLD_N = 1'b1;

// ------------------------------------------------------------------ clocks

wire clk_65, clk_ser, clk_ser_n, clk_sdr_out, mclk;
wire locked;
wire [5:0] pll_clk;
kg_pll #(
	.CLKIN_PERIOD(20.0),
	.DIVCLK_DIVIDE(1),
	.CLKFBOUT_MULT(13),
	.CLKOUT0_DIVIDE(10),
	.CLKOUT1_DIVIDE(2),
	.CLKOUT2_DIVIDE(2), .CLKOUT2_PHASE(180.0),
	.CLKOUT3_DIVIDE(12), .CLKOUT3_PHASE(330.0),
	.CLKOUT4_DIVIDE(12),
	.CLKOUT5_DIVIDE(12),
	.BUFG_MASK(6'b101111)
) pll (
	.clk_in(CLK_50MHZ),
	.rst(1'b0),
	.clk_out(pll_clk),
	.locked(locked)
);
assign clk_65 = pll_clk[0];
assign clk_ser = pll_clk[1];
assign clk_ser_n = pll_clk[2];
assign clk_sdr_out = pll_clk[3];
assign mclk = pll_clk[5];
wire areset_async = ~locked;
wire areset;
kg_sync #(.W(1), .STAGES(3), .INIT(1'b1)) sync_rst (.clk(mclk), .d(areset_async), .q(areset));

// the clock of the FT812 (it must always have one): 65 / 8 = 8.125 MHz
reg [1:0] ft_div = 2'd0;
reg ft_q = 1'b0;
always @(posedge clk_65) begin
	ft_div <= ft_div + 2'd1;
	if (ft_div == 2'd3) ft_q <= ~ft_q;
end
ODDR2 oddr_ft_clk (.Q(FT_CLK_OUT), .C0(clk_65), .C1(~clk_65), .CE(1'b1), .D0(ft_q), .D1(ft_q), .R(1'b0), .S(1'b0));

// ------------------------------------------------------------------ MCU

// MCU_SCK on a global buffer (as tsconf and the menu: on local routing the flip-flops of the SPI
// receiver had several ns of clock skew); the FT812 and SD2 get the IBUFG output (a BUFG drives no pad)
wire mcu_sck_ibufg, mcu_sck;
IBUFG ibufg_mcu_sck (.I(MCU_SCK), .O(mcu_sck_ibufg));
BUFG bufg_mcu_sck (.I(mcu_sck_ibufg), .O(mcu_sck));

// MCU link v2 (karabas-go-firmware docs/link_v2.md, kg_mcu2); INT on IO1
wire mcu_int;
assign MCU_IO[1] = mcu_int;
assign MCU_IO[0] = 1'bz;
assign MCU_IO[5:2] = 4'bzzzz;

wire matrix_cmd_wr;
wire [23:0] matrix_cmd;

wire [55:0] hid_kbd;
wire [15:0] joy_l16, joy_r16;
wire [1:0] ld_kind;
wire [7:0] ld_data;
wire [31:0] ld_addr;
wire [63:0] ld_ext;
wire ld_active, ld_wr;
wire dvi_only;
wire ft_cs_n, ft_mosi, ft_spi_on, sd2_cs_n, sd2_mosi;
wire [6*8-1:0] sw;
wire osd_wr, osd_en, osd_zoom;
wire [11:0] osd_waddr;
wire [7:0] osd_wdata;
wire [23:0] osd_fg, osd_bg;
wire [1:0] osd_alpha, osd_place;
wire [4:0] osd_px, osd_ph;
wire [3:0] osd_py;
wire [5:0] osd_pw;

kg_mcu2 #(
	.CAPS(16'h0000),
	.SW_N(6),
	.CS_FILTER(3),
	.ENABLE_OSD(1),
	.ENABLE_AUX(1),      // MATRIX_CMD: the audio peaks
	.ENABLE_FT(1),
	.ENABLE_SD2(1)
) mcu (
	.CLK(mclk),
	.N_RESET(~areset),

	.MCU_SCK(mcu_sck),
	.MCU_MOSI(MCU_MOSI),
	.MCU_MISO(MCU_MISO),
	.MCU_SS(MCU_CS_N),
	.MCU_INT(mcu_int),
	.MCU_SPI_FT_SS(MCU_IO[3]),
	.MCU_SPI_SD2_SS(MCU_IO[2]),

	.SW(sw), .SW_WR(), .SW_INDEX(), .SW_VALUE(), .HW_ID(), .DVI_ONLY(dvi_only), .CORE_BUILD(), .FW_BUILD(),
	.BUSY(), .BTNS(), .RELOAD_REQ(1'b0), .RELOAD_CORE(8'd0),

	.KBD(hid_kbd), .KBD_WR(), .PS2_CODE(), .PS2_KIND(), .PS2_WR(),
	.MS_X(), .MS_Y(), .MS_Z(), .MS_B(), .MS_WR(),
	.JOY_L(joy_l16), .JOY_R(joy_r16), .JOY_WR(),
	.PS2_CMD(16'h0000), .PS2_CMD_WR(1'b0),

	.LD_KIND(ld_kind), .LD_SLOT(), .LD_SIZE(), .LD_EXT(ld_ext), .LD_START(), .LD_ACTIVE(ld_active), .LD_END(),
	.LD_ADDR(ld_addr), .LD_DATA(ld_data), .LD_WR(ld_wr), .LD_READY(1'b1),

	.OSD_WR(osd_wr), .OSD_WADDR(osd_waddr), .OSD_WDATA(osd_wdata), .OSD_EN(osd_en),
	.OSD_FG(osd_fg), .OSD_BG(osd_bg), .OSD_ALPHA(osd_alpha), .OSD_PX(osd_px), .OSD_PY(osd_py),
	.OSD_PW(osd_pw), .OSD_PH(osd_ph), .OSD_PLACE(osd_place), .OSD_ZOOM(osd_zoom),

	.SDC_IMG_MOUNTED(), .SDC_IMG_SIZE(),
	.SDC_RD(8'd0), .SDC_WR(8'd0), .SDC_SECTOR(32'd0),
	.SDC_BUSY(), .SDC_DONE(), .SDC_ERROR(), .SDC_SLOT(),
	.SDC_BYTE_IN_STROBE(), .SDC_BYTE_ADDR(),
	.SDC_BYTE_IN_DATA(), .SDC_BYTE_OUT_DATA(8'd0),
	.IMG_WP(), .IMG_PHYS_WR(), .IMG_PHYS(), .IMG_FLUSH(), .FDD_CHNG_WR(), .FDD_CHNG(),
	.FDD_CHNG_REQ(1'b0), .FDD_CHNG_DS(2'd0),
	.BK_MOUNT(1'b0), .BK_FLUSHED(1'b0), .BK_SLOT(3'd0), .BK_SIZE(32'd0),
	.BK_KIND(8'd0), .BK_RESULT(8'd0),
	.IMG_ACTIVE(),

	.PORT_OUT_DATA(), .PORT_OUT_WR(), .PORT_OUT_READY(4'b1111), .PORT_IN_DATA(32'd0), .PORT_IN_WR(4'd0),
	.PORT_CFG(128'd0), .PORT_IN_FULL(), .PORT_STAT(), .PORT_STAT_WR(),
	.RTC_A(8'd0), .RTC_DI(8'd0), .RTC_CS(1'b0), .RTC_WR_N(1'b1), .RTC_DO(),
	.MATRIX_CMD(matrix_cmd), .MATRIX_CMD_WR(matrix_cmd_wr), .DEBUG_ADDR(16'd0), .DEBUG_DATA(16'd0),

	.FT_SPI_ON(ft_spi_on), .FT_VGA_ON(), .FT_RESET(), .FT_SCK(), .FT_MOSI(ft_mosi), .FT_MISO(FT_SPI_MISO),
	.FT_CS_N(ft_cs_n),
	.SD2_SCK(), .SD2_MOSI(sd2_mosi), .SD2_MISO(SD_DO), .SD2_CS_N(sd2_cs_n)
);

assign FT_SPI_CS_N = ft_spi_on ? ft_cs_n : 1'b1;
assign FT_SPI_SCK = ft_spi_on ? mcu_sck_ibufg : 1'b1;
assign FT_SPI_MOSI = ft_spi_on ? ft_mosi : 1'b1;
assign SD_CS_N = sd2_cs_n;
assign SD_DI = sd2_mosi;
assign SD_CLK = mcu_sck_ibufg;

// ------------------------------------------------------------------ soft switches (the SW registers of kg_mcu2)

wire sw_japan = sw[0*8];      // 0 Export, 1 Japan (the region of the I/O port 3F)
wire sw_pal = sw[1*8];        // 0 NTSC, 1 PAL
wire sw_fm_off = sw[2*8];     // 0 FM on, 1 off
wire sw_border = sw[3*8];
wire sw_swap = sw[4*8];
wire sw_reset = sw[5*8];

// ------------------------------------------------------------------ cartridge

wire file_active = ld_active && ld_kind == 2'd1;
wire file_wr = ld_wr && ld_kind == 2'd1;

wire [23:0] ld_waddr;
wire [15:0] ld_wdata;
wire ld_we, ld_we_ack;
wire [21:0] cart_mask;
wire romhdr, cart_gg, cart_sg, cart_sc, loading, cart_ready;
sms_loader loader (
	.clk(mclk),
	.file_active(file_active), .file_wr(file_wr), .file_addr(ld_addr), .file_data(ld_data), .file_ext(ld_ext),
	.sdr_waddr(ld_waddr), .sdr_din(ld_wdata), .sdr_we(ld_we),
	.cart_mask(cart_mask), .romhdr(romhdr), .gg(cart_gg), .sg(cart_sg), .sc(cart_sc),
	.loading(loading), .cart_ready(cart_ready)
);

// reset: the PLL, the Reset item, while a cartridge loads, until the first one is in
reg [7:0] rst_cnt = 8'd0;
reg sms_reset_n = 1'b0;
always @(posedge mclk) begin
	if (areset || sw_reset || loading || !cart_ready)
		rst_cnt <= 8'd0;
	else if (rst_cnt != 8'hFF)
		rst_cnt <= rst_cnt + 8'd1;
	sms_reset_n <= rst_cnt == 8'hFF;
end

// ------------------------------------------------------------------ pads

// mcu JOY_L / JOY_R: [0] connected, [1] up, [2] down, [3] left, [4] right, [5] start, [6] A, [7] B,
// [8] C, ... (1 = pressed); the keyboard as two pads the same way (sms_kbd)
wire [12:0] kb_l, kb_r;
sms_kbd kbd (
	.clk(mclk),
	.kb_dat0(hid_kbd[15:8]), .kb_dat1(hid_kbd[23:16]), .kb_dat2(hid_kbd[31:24]),
	.kb_dat3(hid_kbd[39:32]), .kb_dat4(hid_kbd[47:40]), .kb_dat5(hid_kbd[55:48]),
	.kb_l(kb_l), .kb_r(kb_r)
);
wire [12:0] pad1 = sw_swap ? (joy_r16[12:0] | kb_r) : (joy_l16[12:0] | kb_l);
wire [12:0] pad2 = sw_swap ? (joy_l16[12:0] | kb_l) : (joy_r16[12:0] | kb_r);
// SMS port bits (active low): th tr tl right left down up; button 1 (TL) = A, button 2 (TR) = B or C
wire [6:0] j1 = ~{ 1'b0, pad1[7] | pad1[8], pad1[6], pad1[4], pad1[3], pad1[2], pad1[1] };
wire [6:0] j2 = ~{ 1'b0, pad2[7] | pad2[8], pad2[6], pad2[4], pad2[3], pad2[2], pad2[1] };
wire pause_n = ~(pad1[5] | pad2[5]);

// ------------------------------------------------------------------ the machine

wire ce_cpu, ce_pix, hsync, vsync, hblank, vblank;
wire [8:0] vx, vy;
wire [11:0] color;
wire [15:0] snd_l, snd_r;
wire rom_rd;
wire [23:0] rom_a;
wire [7:0] rom_do;
wire [14:0] nvram_a;
wire [7:0] nvram_d, nvram_q;
wire nvram_we;

sms_machine #(.FM(1'b1)) sms (
	.clk_sys(mclk),
	.reset_n(sms_reset_n),
	.gg(cart_gg),
	.pal(sw_pal),
	.region(sw_japan),
	.border(sw_border),
	.sc3000_en(cart_sc),
	.sk1100_en(1'b0),
	.mapper_lock(1'b0),
	.cart_in(cart_ready),
	.fm_on(~sw_fm_off),
	.ce_cpu_o(ce_cpu),
	.rom_rd(rom_rd), .rom_a(rom_a), .rom_do(rom_do),
	.j1(j1), .j2(j2), .pause(pause_n),
	.sk1100_row_sel(), .sk1100_row_data(12'hFFF),
	.ce_pix(ce_pix), .x(vx), .y(vy), .color(color), .smode_M1(), .smode_M3(),
	.hsync(hsync), .vsync(vsync), .hblank(hblank), .vblank(vblank),
	.audioL(snd_l), .audioR(snd_r),
	.nvram_a(nvram_a), .nvram_d(nvram_d), .nvram_we(nvram_we), .nvram_q(nvram_q)
);

// the cartridge RAM (32 KB, block RAM; saved to SD in Ф2)
kg_spram #(.DW(8), .AW(15)) nvram (
	.clk(mclk), .en(1'b1), .we(nvram_we), .addr(nvram_a), .din(nvram_d), .dout(nvram_q)
);

// ------------------------------------------------------------------ SDRAM

wire sdr_cs_n;
sms_sdram sdram (
	.SDRAM_DQ(SDR_DQ),
	.SDRAM_A(SDR_A),
	.SDRAM_DQML(SDR_DQM[0]),
	.SDRAM_DQMH(SDR_DQM[1]),
	.SDRAM_BA(SDR_BA),
	.SDRAM_nCS(sdr_cs_n),
	.SDRAM_nWE(SDR_WE_N),
	.SDRAM_nRAS(SDR_RAS_N),
	.SDRAM_nCAS(SDR_CAS_N),
	.init(areset),
	.clk(mclk),
	.clkref(ce_cpu),
	.raddr({ 3'b000, rom_a[21:0] & cart_mask } + (romhdr ? 25'd512 : 25'd0)),
	.rd(rom_rd),
	.rd_rdy(),
	.dout(rom_do),
	.waddr(ld_waddr),
	.din(ld_wdata),
	.we(ld_we),
	.we_ack(ld_we_ack)
);
// FLASH_CS_N (T3) is the SDRAM /CS of Mini G2 (rev G: tied low on the board)
assign FLASH_CS_N = sdr_cs_n;
ODDR2 oddr_sdr_clk (.Q(SDR_CLK), .C0(clk_sdr_out), .C1(~clk_sdr_out), .CE(1'b1), .D0(1'b1), .D1(1'b0), .R(1'b0), .S(1'b0));

// ------------------------------------------------------------------ video

wire [23:0] vid_rgb;
wire vid_hs, vid_vs, vid_de;
sms_fb fb (
	.clk(mclk),
	.r(color[3:0]),
	.g(color[7:4]),
	.b(color[11:8]),
	.hbl(hblank),
	.vbl(vblank),
	.ce_pix(ce_pix),
	.MA(MA),
	.MD(MD),
	.MWR_N(MWR_N),
	.MRD_N(MRD_N),
	.clk_65(clk_65),
	.rgb(vid_rgb),
	.hs(vid_hs),
	.vs(vid_vs),
	.de(vid_de)
);

// the bitmap OSD of link v2 (kg_l2_osd_overlay): written in mclk, drawn in clk_65
wire [23:0] osd_rgb;
wire osd_hs, osd_vs, osd_de;
kg_l2_osd_overlay osd (
	.wclk(mclk),
	.osd_wr(osd_wr), .osd_waddr(osd_waddr), .osd_wdata(osd_wdata), .osd_en(osd_en),
	.osd_fg(osd_fg), .osd_bg(osd_bg), .osd_alpha(osd_alpha), .osd_px(osd_px), .osd_py(osd_py),
	.osd_pw(osd_pw), .osd_ph(osd_ph), .osd_place(osd_place), .osd_zoom(osd_zoom),
	.icon_on(8'd0), .icon_act(8'd0),
	.clk(clk_65),
	.rgb_i(vid_rgb), .hs_i(vid_hs), .vs_i(vid_vs), .de_i(vid_de),
	.rgb_o(osd_rgb), .hs_o(osd_hs), .vs_o(osd_vs), .de_o(osd_de)
);

// ------------------------------------------------------------------ audio

// the ADC (PCM1808: the line in and the MIDI synth SAM2695 of the board): i2s_transceiver is the master
// on MCLK, BCK = MCLK / 16 (3.39 MHz), LRCK = BCK / 64 (52.9 kHz); SCKI = ADC_CLK = MCLK / 2 (27.08 MHz =
// 512 fs), 24 bits; half of the scale into the mix
wire [23:0] adc_l, adc_r;
i2s_transceiver #(.mclk_sclk_ratio(16), .sclk_ws_ratio(64), .d_width(24)) adc (
	.reset_n(~areset),
	.mclk(mclk),
	.sclk(ADC_BCK),
	.ws(ADC_LRCK),
	.sd_tx(),
	.sd_rx(ADC_DOUT),
	.l_data_tx(24'b0),
	.r_data_tx(24'b0),
	.l_data_rx(adc_l),
	.r_data_rx(adc_r)
);
reg adc_scki = 1'b0;
always @(posedge mclk) adc_scki <= ~adc_scki;
ODDR2 oddr_adc (.Q(ADC_CLK), .C0(mclk), .C1(~mclk), .CE(1'b1), .D0(adc_scki), .D1(adc_scki), .R(1'b0), .S(1'b0));

// the machine audio (signed 16 bits, MiSTer AUDIO_S = 1) + the ADC / 2, saturated, taken at 48 kHz of
// MCLK: 54.1667 MHz = 650 / 12 MHz, 48 kHz / MCLK = 72 / 81250 exactly
function [15:0] sat16(input [17:0] v);
	sat16 = (v[17:15] == 3'b000 || v[17:15] == 3'b111) ? v[15:0] : v[17] ? 16'h8000 : 16'h7FFF;
endfunction
wire [17:0] mix_l = { {2{snd_l[15]}}, snd_l } + { {3{adc_l[23]}}, adc_l[23:9] };
wire [17:0] mix_r = { {2{snd_r[15]}}, snd_r } + { {3{adc_r[23]}}, adc_r[23:9] };

reg [16:0] aud_acc = 17'd0;
reg [15:0] aud_l = 16'd0, aud_r = 16'd0;
reg aud_t = 1'b0;
always @(posedge mclk) begin
	if (aud_acc >= 17'd81250 - 17'd72) begin
		aud_acc <= aud_acc + 17'd72 - 17'd81250;
		aud_l <= sat16(mix_l);
		aud_r <= sat16(mix_r);
		aud_t <= ~aud_t;
	end
	else
		aud_acc <= aud_acc + 17'd72;
end

// the level meters of the mcu: the peaks of the final mix (CMD_AUDIO_PEAKS_L / _R)
audio_peaks #(.PERIOD_BITS(19)) peaks (.clk(mclk), .audio_l(aud_l), .audio_r(aud_r), .cmd_wr(matrix_cmd_wr), .cmd(matrix_cmd));

kg_pcm5102 #(.DIV_BITS(2)) dac (  // bck 3.39 MHz, 105.8 kHz
	.clk(mclk),
	.reset(areset),
	.left(aud_l),
	.right(aud_r),
	.din(DAC_DAT),
	.bck(DAC_BCK),
	.lrck(DAC_WS)
);

// into clk_65 for HDMI: the toggle of a new sample (the samples hold for 1128 MCLK)
reg [2:0] aud_ts = 3'd0;
reg aud_stb = 1'b0;
reg [23:0] hdmi_l = 24'd0, hdmi_r = 24'd0;
always @(posedge clk_65) begin
	aud_ts <= { aud_ts[1:0], aud_t };
	aud_stb <= aud_ts[2] != aud_ts[1];
	if (aud_ts[2] != aud_ts[1]) begin
		hdmi_l <= { aud_l, 8'd0 };
		hdmi_r <= { aud_r, 8'd0 };
	end
end

// ------------------------------------------------------------------ HDMI

wire dvi_only_65;
kg_sync #(.W(1), .STAGES(3)) sync_dvi (.clk(clk_65), .d(dvi_only), .q(dvi_only_65));

// OUTPUT_REG / INPUT_REG: registers around the encoders (1024 x 768: negative syncs, VESA)
hdmi_tx #(.SAMPLE_FREQ(48000), .INPUT_REG(1), .OUTPUT_REG(1)) hdmi (
	.clk(clk_65),
	.sclk(clk_ser),
	.sclk_n(clk_ser_n),
	.reset(areset_async),
	.rgb(osd_rgb),
	.vsync(~osd_vs),
	.hsync(~osd_hs),
	.de(osd_de),
	.audio_en(~dvi_only_65),
	.audio_l(hdmi_l),
	.audio_r(hdmi_r),
	.audio_clk(aud_stb),
	.tx_clk_n(TMDS_N[3]),
	.tx_clk_p(TMDS_P[3]),
	.tx_d_n(TMDS_N[2:0]),
	.tx_d_p(TMDS_P[2:0])
);

endmodule
