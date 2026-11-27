`timescale 1ns / 1ps
`default_nettype wire

/*
 sim_top.v - the board path of the cartridge for the verilator simulation (sim_sms.cpp with -DSIM_SYS):
 the file bytes (as LD kind 1 of kg_mcu2) -> sms_loader -> sms_sdram -> sdram_model, and the machine
 reading its ROM through sms_sdram, held in reset while the file comes, as karabas_minig_top.v.
*/

module sim_top (
	input  wire        clk_sys,
	input  wire        file_active,
	input  wire        file_wr,
	input  wire [31:0] file_addr,
	input  wire [7:0]  file_data,
	input  wire [63:0] file_ext,
	input  wire        pal,
	input  wire        border,
	input  wire        fm_on,
	input  wire [6:0]  j1,
	input  wire [6:0]  j2,
	input  wire        pause,

	output wire        ce_pix,
	output wire [8:0]  x,
	output wire [8:0]  y,
	output wire [11:0] color,
	output wire        hsync,
	output wire        vsync,
	output wire        hblank,
	output wire        vblank,
	output wire [15:0] audioL,
	output wire [15:0] audioR,
	output wire        loading,
	output wire        cart_ready,
	output wire        gg,
	output wire [31:0] sdram_errors
);

wire [23:0] ld_waddr;
wire [15:0] ld_wdata;
wire ld_we, ld_we_ack;
wire [21:0] cart_mask;
wire romhdr, sg, sc;
sms_loader loader (
	.clk(clk_sys),
	.file_active(file_active), .file_wr(file_wr), .file_addr(file_addr), .file_data(file_data), .file_ext(file_ext),
	.sdr_waddr(ld_waddr), .sdr_din(ld_wdata), .sdr_we(ld_we),
	.cart_mask(cart_mask), .romhdr(romhdr), .gg(gg), .sg(sg), .sc(sc),
	.loading(loading), .cart_ready(cart_ready)
);

reg [7:0] rst_cnt = 8'd0;
reg reset_n = 1'b0;
always @(posedge clk_sys) begin
	if (loading || !cart_ready)
		rst_cnt <= 8'd0;
	else if (rst_cnt != 8'hFF)
		rst_cnt <= rst_cnt + 8'd1;
	reset_n <= rst_cnt == 8'hFF;
end

wire ce_cpu, rom_rd;
wire [23:0] rom_a;
wire [7:0] rom_do;
wire [14:0] nvram_a;
wire [7:0] nvram_d;
wire nvram_we;
reg [7:0] nvram [0:32767];
reg [7:0] nvram_q = 8'hFF;
always @(posedge clk_sys) begin
	if (nvram_we) nvram[nvram_a] <= nvram_d;
	nvram_q <= nvram[nvram_a];
end

sms_machine sms (
	.clk_sys(clk_sys), .reset_n(reset_n), .gg(gg), .ggres(gg), .palettemode(sg | sc), .pal(pal), .region(1'b0), .border(border),
	.sc3000_en(sc), .sk1100_en(1'b0), .mapper_lock(1'b0), .cart_in(cart_ready), .fm_on(fm_on),
	.ce_cpu_o(ce_cpu),
	.rom_rd(rom_rd), .rom_a(rom_a), .rom_do(rom_do),
	.j1(j1), .j2(j2), .pause(pause),
	.sk1100_row_sel(), .sk1100_row_data(12'hFFF),
	.ce_pix(ce_pix), .x(x), .y(y), .color(color), .smode_M1(), .smode_M3(),
	.hsync(hsync), .vsync(vsync), .hblank(hblank), .vblank(vblank),
	.audioL(audioL), .audioR(audioR),
	.nvram_a(nvram_a), .nvram_d(nvram_d), .nvram_we(nvram_we), .nvram_q(nvram_q)
);

wire [15:0] dq;
wire [12:0] sa;
wire [1:0] ba;
wire cs_n, ras_n, cas_n, we_n, dqml, dqmh;
sms_sdram sdram (
	.SDRAM_DQ(dq), .SDRAM_A(sa), .SDRAM_DQML(dqml), .SDRAM_DQMH(dqmh), .SDRAM_BA(ba),
	.SDRAM_nCS(cs_n), .SDRAM_nWE(we_n), .SDRAM_nRAS(ras_n), .SDRAM_nCAS(cas_n),
	.init(1'b0), .clk(clk_sys), .clkref(ce_cpu),
	.raddr({ 3'b000, rom_a[21:0] & cart_mask } + (romhdr ? 25'd512 : 25'd0)),
	.rd(rom_rd), .rd_rdy(), .dout(rom_do),
	.waddr(ld_waddr), .din(ld_wdata), .we(ld_we), .we_ack(ld_we_ack)
);

sdram_model chip (
	.clk(clk_sys), .dq(dq), .a(sa), .ba(ba), .cs_n(cs_n), .ras_n(ras_n), .cas_n(cas_n), .we_n(we_n),
	.dqml(dqml), .dqmh(dqmh), .errors(sdram_errors)
);

endmodule
