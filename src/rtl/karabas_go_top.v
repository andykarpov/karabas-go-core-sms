`timescale 1ns / 1ps
`default_nettype wire

/*
 Sega Master System / Game Gear / SG-1000 core for Karabas Go (VGA, PCM5102, no ADC). Made by
 tools/mktops.py from karabas_minig_top.v (do not edit: change that one and run it): the same
 except the pins, the MCU link (MCU_SCK not on a clock pin), no ADC (line in) and the video: 24 bit
 RGB to the VGA DAC with its pixel clock on V_CLK (clk_65 inverted), the FT812 off that bus
 (FT_OE_N = 1). The floppy connector is not used (its outputs 0).
 The machine of SMS_MiSTer (rtl/karabas/sms_machine.vhd) with the board glue of karabas-go-modules.

 Clocks: one PLL, VCO 650 MHz (50 * 13):
   pll_clk<5> MCLK 54.17 MHz (/12): the machine (MiSTer 53.69: 0.9 % fast), its SDRAM controller, the
              mcu link, the loader, the pads, the frame buffer writes and the SRAM, the audio
   pll_clk<3> 54.17 MHz (/12, 330 degrees = -1.54 ns): SDR_CLK through an ODDR2: the chip a little ahead
   pll_clk<0> 65.0 MHz (/10): the video out (1024 x 768 at 60 Hz, VGA, V_CLK), the OSD
   (pll_clk<1>, <2>, the HDMI serialiser of Mini / Mini G, are not used here)
 clk_65 is crossed with synchronisers, a toggle handshake and the line buffer of sms_fb (TIG).

 Memory: the cartridge ROM (up to 4 MB) in the SDRAM (sms_sdram: the controller of SMS_MiSTer, one
 access per CPU cycle); work RAM and VRAM in block RAM; the cartridge RAM (32 KB, also the 93C46
 EEPROM of the Game Gear cartridges that have one) in block RAM, its second port for kg_bk_ram; the
 SRAM holds the frame buffers of sms_fb (x 4 = 1024 x 768 for 256 x 192, x 5 for the Game Gear).

 Saves: the cartridge RAM in a .sav file next to the game (32 KB, as MiSTer: mounted for every game,
 the firmware creates it), through kg_bk_ram on img slot 0: loaded before the CPU starts, saved a
 second after the game writes it.

 The system from the extension of the file (sms_loader): .gg = Game Gear (its 160 x 144 window, its
 palette), .sg = SG-1000 (the TMS9918 palette), .sc = SC-3000 (+ the SK-1100 keyboard from the USB
 keyboard, sms_sk1100), else Master System.

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

module karabas_go_top (
	input wire CLK_50MHZ,

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
assign UART_RX = 1'bz;
assign UART_TX = 1'bz;
assign UART_CTS = 1'bz;
assign MIDI_TX = 1'b1;
assign ESP_RESET_N = 1'bz;
assign ESP_BOOT_N = 1'bz;
assign MIDI_CLK = 1'b0;      // the SAM2695 synth: held in reset, no use for it here
assign MIDI_RESET_N = 1'b0;
assign FT_OE_N = 1'b1;     // the FT812 does not drive the video DAC
assign BEEPER = 1'b0;
assign DAC_MUTE = 1'b1;    // soft mute of the PCM5102: 1 = sound on

// the floppy connector is not used: its outputs 0 (the board inverts them: high = active)
assign FDC_DRIVE = 2'b00;
assign FDC_MOTOR = 1'b0;
assign FDC_DIR = 1'b0;
assign FDC_STEP = 1'b0;
assign FDC_WDATA = 1'b0;
assign FDC_WGATE = 1'b0;
assign FDC_SIDE_N = 1'b0;

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

// the pixel clock of the VGA DAC: clk_65 inverted (the DAC takes the pixel at the rising edge of V_CLK,
// in the middle of the data of a rising clk_65; karabas-go notes go-vclk-phase)
ODDR2 oddr_v_clk (.Q(V_CLK), .C0(clk_65), .C1(~clk_65), .CE(1'b1), .D0(1'b0), .D1(1'b1), .R(1'b0), .S(1'b0));

// ------------------------------------------------------------------ MCU

// MCU_SCK is not on a clock pin before rev.G (CLOCK_DEDICATED_ROUTE = FALSE in the ucf)
wire mcu_sck = MCU_SCK, mcu_sck_ibufg = MCU_SCK;

// MCU link v2 (karabas-go-firmware docs/link_v2.md, kg_mcu2); INT on IO1
wire mcu_int;
// INT of link v2 on MCU_SPI_IO[0] (N9, the IO1 line of the firmware)
assign MCU_SPI_IO[0] = mcu_int;
assign MCU_SPI_IO[1] = 1'bz;

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
wire [8*8-1:0] sw;
// the .sav file of kg_bk_ram (slot 0) on the mounter of kg_mcu2
wire [7:0] img_flush, sdc_img_mounted, sdc_rd, sdc_wr, sdc_byte_in_data, sdc_byte_out_data, bk_kind, bk_result;
wire [63:0] sdc_img_size;
wire [31:0] sdc_sector, bk_size;
wire sdc_busy, sdc_done, sdc_error, sdc_byte_in_strobe, bk_mount, bk_flushed;
wire [2:0] sdc_slot;
wire [8:0] sdc_byte_addr;
wire osd_wr, osd_en, osd_zoom;
wire [11:0] osd_waddr;
wire [7:0] osd_wdata;
wire [23:0] osd_fg, osd_bg;
wire [1:0] osd_alpha, osd_place;
wire [4:0] osd_px, osd_ph;
wire [3:0] osd_py;
wire [5:0] osd_pw;

kg_mcu2 #(
	.CAPS(16'h0002),     // backup RAM: the firmware flushes the .sav before a new game
	.SW_N(8),
	.CS_FILTER(3),
	.ENABLE_OSD(1),
	.ENABLE_IMG(1),      // the .sav file of kg_bk_ram
	.IMG_OUT_LATENCY(2), // the sector buffer of kg_bk_ram
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
	.MCU_SPI_FT_SS(MCU_SPI_FT_CS_N),
	.MCU_SPI_SD2_SS(MCU_SPI_SD2_CS_N),

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

	.SDC_IMG_MOUNTED(sdc_img_mounted), .SDC_IMG_SIZE(sdc_img_size),
	.SDC_RD(sdc_rd), .SDC_WR(sdc_wr), .SDC_SECTOR(sdc_sector),
	.SDC_BUSY(sdc_busy), .SDC_DONE(sdc_done), .SDC_ERROR(sdc_error), .SDC_SLOT(sdc_slot),
	.SDC_BYTE_IN_STROBE(sdc_byte_in_strobe), .SDC_BYTE_ADDR(sdc_byte_addr),
	.SDC_BYTE_IN_DATA(sdc_byte_in_data), .SDC_BYTE_OUT_DATA(sdc_byte_out_data),
	.IMG_WP(), .IMG_PHYS_WR(), .IMG_PHYS(), .IMG_FLUSH(img_flush), .FDD_CHNG_WR(), .FDD_CHNG(),
	.FDD_CHNG_REQ(1'b0), .FDD_CHNG_DS(2'd0),
	.BK_MOUNT(bk_mount), .BK_FLUSHED(bk_flushed), .BK_SLOT(3'd0), .BK_SIZE(bk_size),
	.BK_KIND(bk_kind), .BK_RESULT(bk_result),
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
wire sw_black_col = sw[5*8];  // the masked left column: 0 backdrop, 1 black
wire sw_sp_all = sw[6*8];     // sprites per line: 0 standard, 1 all
wire sw_reset = sw[7*8];

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

// ------------------------------------------------------------------ save (.sav)

// kg_bk_ram on img slot 0: 64 sectors (32 KB), started when a cartridge is in (loading falls); a new
// file resets it (the firmware flushes the old one before it loads another game). Every write of the
// machine to the cartridge RAM marks its sector.
reg file_active_d = 1'b0, loading_d = 1'b0, bk_reset = 1'b0, bk_start = 1'b0;
always @(posedge mclk) begin
	file_active_d <= file_active;
	loading_d <= loading;
	bk_reset <= file_active && !file_active_d;
	bk_start <= loading_d && !loading;
end

wire [14:0] nvram_a;
wire [7:0] nvram_d, nvram_q;
wire nvram_we;
wire bk_busy, bk_mem_req, bk_mem_we;
wire [14:0] bk_mem_addr;
wire [7:0] bk_mem_din, bk_mem_dout;
reg bk_mem_ack = 1'b0;
kg_bk_ram #(
	.SLOT(3'd0),
	.IDLE_CLOCKS(27'd54167000),    // ~1 s at 54.17 MHz: save after the last write
	.MAX_CLOCKS(27'd108333000),    // ~2 s: at the latest after the first write
	.MOUNT_CLOCKS(27'd54167000),   // ~1 s: no answer to the mount, go on without a save
	.GRACE_CLOCKS(27'd541670),     // ~10 ms: no file
	.LINK(2),                      // on the mounter of kg_mcu2
	.SBITS(6)                      // 64 sectors = 32 KB
) bk_ram (
	.clk(mclk),
	.reset(bk_reset),
	.start(bk_start),
	.size(7'd64),
	.kind(8'h00),
	.busy(bk_busy),
	.mounted(),
	.saving(),
	.save_error(),
	.wr(nvram_we),
	.wr_addr(nvram_a),
	.mem_req(bk_mem_req),
	.mem_we(bk_mem_we),
	.mem_addr(bk_mem_addr),
	.mem_din(bk_mem_din),
	.mem_ack(bk_mem_ack),
	.mem_dout(bk_mem_dout),
	.img_mounted(8'd0), .img_size(64'd0), .img_data_wr(1'b0), .img_data_addr(9'd0), .img_data(8'd0),
	.img_result_wr(1'b0), .img_result(8'd0), .img_sum(16'd0), .img_flush(img_flush),
	.img_q_wr(), .img_q_di(), .img_q_ack(1'b0),
	.sdc_img_mounted_i(sdc_img_mounted), .sdc_img_size_i(sdc_img_size), .sdc_rd_o(sdc_rd),
	.sdc_wr_o(sdc_wr), .sdc_sector_o(sdc_sector), .sdc_busy_i(sdc_busy), .sdc_done_i(sdc_done),
	.sdc_error_i(sdc_error), .sdc_slot_i(sdc_slot), .sdc_byte_in_strobe_i(sdc_byte_in_strobe),
	.sdc_byte_addr_i(sdc_byte_addr), .sdc_byte_in_data_i(sdc_byte_in_data),
	.sdc_byte_out_data_o(sdc_byte_out_data),
	.bk_mount(bk_mount), .bk_flushed(bk_flushed), .bk_size(bk_size), .bk_kind(bk_kind),
	.bk_result(bk_result)
);
// the memory port: the second port of the cartridge RAM, the data one clock after the request
always @(posedge mclk) bk_mem_ack <= bk_mem_req && !bk_mem_ack;

// reset: the PLL, the Reset item, while a cartridge loads, until the first one is in, while the
// .sav file loads
reg [7:0] rst_cnt = 8'd0;
reg sms_reset_n = 1'b0;
always @(posedge mclk) begin
	if (areset || sw_reset || loading || !cart_ready || bk_busy)
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

// the SK-1100 keyboard of the SC-3000 (row 7: the joysticks, as MiSTer)
wire [2:0] sk_row_sel;
wire [11:0] sk_row_data;
sms_sk1100 sk1100 (
	.clk(mclk),
	.enable(cart_sc),
	.kbd(hid_kbd),
	.joy_row({ j2[5], j2[4], j2[3], j2[2], j2[1], j2[0], j1[5], j1[4], j1[3], j1[2], j1[1], j1[0] }),
	.row_sel(sk_row_sel),
	.row_data(sk_row_data)
);

// ------------------------------------------------------------------ the machine

wire ce_cpu, ce_pix, hsync, vsync, hblank, vblank;
wire [8:0] vx, vy;
wire [11:0] color;
wire [15:0] snd_l, snd_r;
wire rom_rd;
wire [23:0] rom_a;
wire [7:0] rom_do;
sms_machine #(.FM(1'b1)) sms (
	.clk_sys(mclk),
	.reset_n(sms_reset_n),
	.gg(cart_gg),
	.ggres(cart_gg),
	.palettemode(cart_sg | cart_sc),
	.pal(sw_pal),
	.region(sw_japan),
	.border(sw_border),
	.black_column(sw_black_col),
	.sp64(sw_sp_all),
	.sc3000_en(cart_sc),
	.sk1100_en(cart_sc),
	.mapper_lock(1'b0),
	.cart_in(cart_ready),
	.fm_on(~sw_fm_off),
	.ce_cpu_o(ce_cpu),
	.rom_rd(rom_rd), .rom_a(rom_a), .rom_do(rom_do),
	.j1(j1), .j2(j2), .pause(pause_n),
	.sk1100_row_sel(sk_row_sel), .sk1100_row_data(sk_row_data),
	.ce_pix(ce_pix), .x(vx), .y(vy), .color(color), .smode_M1(), .smode_M3(),
	.hsync(hsync), .vsync(vsync), .hblank(hblank), .vblank(vblank),
	.audioL(snd_l), .audioR(snd_r),
	.nvram_a(nvram_a), .nvram_d(nvram_d), .nvram_we(nvram_we), .nvram_q(nvram_q)
);

// the cartridge RAM (32 KB, block RAM): port A the machine, port B kg_bk_ram
kg_tdpram #(.DW(8), .AW(15)) nvram (
	.clka(mclk), .ena(1'b1), .wea(nvram_we), .addra(nvram_a), .dina(nvram_d), .douta(nvram_q),
	.clkb(mclk), .enb(1'b1), .web(bk_mem_req & bk_mem_we & ~bk_mem_ack), .addrb(bk_mem_addr),
	.dinb(bk_mem_din), .doutb(bk_mem_dout)
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
// the SDRAM /CS is hard wired on Go: sdr_cs_n is not used; FLASH_CS_N is the flash chip
assign FLASH_CS_N = 1'b1;
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

// no ADC (PCM1808) on Go: no line in
wire [23:0] adc_l = 24'd0, adc_r = 24'd0;

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

// DIV_BITS 3: bck 1.69 MHz, 52.9 kHz. With DIV_BITS 2 (105.8 kHz, as core-sega) the user heard hiss on the
// DAC output (not on HDMI) and suspected the PCM5102 losing its lock at that clock (2026-11-27, to confirm)
kg_pcm5102 #(.DIV_BITS(3)) dac (
	.clk(mclk),
	.reset(areset),
	.left(aud_l),
	.right(aud_r),
	.din(DAC_DAT),
	.bck(DAC_BCK),
	.lrck(DAC_LRCK)
);

// ------------------------------------------------------------------ VGA

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

endmodule
