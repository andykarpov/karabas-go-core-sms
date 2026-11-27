`timescale 1ns / 1ps
`default_nettype wire

/*
 sms_sdram.v

 The SDRAM controller of SMS_MiSTer (rtl/sdram.sv, Sorgelig 2018 after Till Harbaum, GPL-3.0 or
 later) in Verilog-2001 for XST, for the one 16M x 16 chip of the boards; karabas: the write port
 takes 16-bit words (the loader gives two bytes at a time), the read port stays byte wide.

 One access per cycle of 8 clocks; the cycle restarts on every rising edge of clkref (ce_cpu of the
 machine: 15 clocks at 54 MHz, so a cycle always completes), refresh when no request is there.
 CAS latency 2, no burst. clk = MCLK (54.17 MHz); the chip clock is MCLK a little ahead (the top).

 Read: a rising edge of rd starts a read of raddr (a byte address) at the next cycle; dout is the
 byte at the end of it (rd_rdy high again). Write: we != we_ack starts a write of din (a word) at
 waddr (a word address); we_ack follows we when it is done.
*/

module sms_sdram (
	inout  wire [15:0] SDRAM_DQ,
	output reg  [12:0] SDRAM_A = 13'd0,
	output wire        SDRAM_DQML,
	output wire        SDRAM_DQMH,
	output reg  [1:0]  SDRAM_BA = 2'd0,
	output reg         SDRAM_nCS = 1'b1,
	output reg         SDRAM_nWE = 1'b1,
	output reg         SDRAM_nRAS = 1'b1,
	output reg         SDRAM_nCAS = 1'b1,

	input  wire        init,       // high until the clocks are good
	input  wire        clk,
	input  wire        clkref,

	input  wire [24:0] raddr,      // byte address
	input  wire        rd,
	output reg         rd_rdy = 1'b0,
	output wire [7:0]  dout,

	input  wire [23:0] waddr,      // word address
	input  wire [15:0] din,
	input  wire        we,
	output reg         we_ack = 1'b0
);

// no burst, CAS 2, single writes
localparam RASCAS_DELAY = 4'd2;
localparam [12:0] MODE = { 3'b000, 1'b1, 2'b00, 3'd2, 1'b0, 3'b000 };

localparam STATE_IDLE  = 4'd0;
localparam STATE_START = 4'd1;
localparam STATE_CONT  = STATE_START + RASCAS_DELAY;   // 3
localparam STATE_READY = STATE_CONT + 4'd2 + 4'd1;      // 6
localparam STATE_LAST  = 4'd7;

reg [3:0]  q = STATE_IDLE;
reg [22:0] a = 23'd0;          // byte address in the bank (a[0] = the byte of a read)
reg [1:0]  bank = 2'd0;
reg [15:0] data = 16'd0;
reg [15:0] sd_dat = 16'd0;
reg        wr = 1'b0;
reg        ram_req = 1'b0;
reg        old_ref = 1'b0, old_rd = 1'b0;

assign dout = a[0] ? sd_dat[15:8] : sd_dat[7:0];

// access manager
always @(posedge clk) begin
	old_ref <= clkref;

	if (q == STATE_IDLE) begin
		old_rd <= rd;
		rd_rdy <= 1'b1;
		ram_req <= 1'b0;
		wr <= 1'b0;

		if (we_ack != we) begin
			ram_req <= 1'b1;
			wr <= 1'b1;
			{ bank, a } <= { waddr, 1'b0 };
			data <= din;
		end
		else if (!old_rd && rd) begin
			rd_rdy <= 1'b0;
			ram_req <= 1'b1;
			wr <= 1'b0;
			{ bank, a } <= raddr;
		end
	end

	if (q == STATE_READY && ram_req) begin
		if (wr) we_ack <= we;
		else rd_rdy <= 1'b1;
	end

	if (q != 4'd15) q <= q + 4'd1;
	if (!old_ref && clkref) q <= STATE_IDLE;
end

// initialization
localparam MODE_NORMAL = 2'b00;
localparam MODE_RESET  = 2'b01;
localparam MODE_LDM    = 2'b10;
localparam MODE_PRE    = 2'b11;

reg [1:0] mode = MODE_RESET;
reg [4:0] reset = 5'h1f;
reg       init_old = 1'b0;
always @(posedge clk) begin
	init_old <= init;
	if (init_old && !init) reset <= 5'h1f;
	else if (q == STATE_LAST) begin
		if (reset != 5'd0) begin
			reset <= reset - 5'd1;
			if (reset == 5'd14) mode <= MODE_PRE;
			else if (reset == 5'd3) mode <= MODE_LDM;
			else mode <= MODE_RESET;
		end
		else
			mode <= MODE_NORMAL;
	end
end

localparam CMD_INHIBIT      = 4'b1111;
localparam CMD_ACTIVE       = 4'b0011;
localparam CMD_READ         = 4'b0101;
localparam CMD_WRITE        = 4'b0100;
localparam CMD_PRECHARGE    = 4'b0010;
localparam CMD_AUTO_REFRESH = 4'b0001;
localparam CMD_LOAD_MODE    = 4'b0000;

// the data bus: driven in the write command cycle only
reg        dq_oe = 1'b0;
reg [15:0] dq_out = 16'd0;
assign SDRAM_DQ = dq_oe ? dq_out : 16'hzzzz;
// karabas: words are written whole, a read takes both bytes: the masks stay 0 (A[12:11] of MiSTer
// were the byte masks of a byte write)
assign SDRAM_DQML = 1'b0;
assign SDRAM_DQMH = 1'b0;

always @(posedge clk) begin
	{ SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE } <= CMD_INHIBIT;
	if (mode == MODE_NORMAL) begin
		if (q == STATE_START)
			{ SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE } <= ram_req ? CMD_ACTIVE : CMD_AUTO_REFRESH;
		else if (q == STATE_CONT && ram_req)
			{ SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE } <= wr ? CMD_WRITE : CMD_READ;
	end
	else if (q == STATE_START) begin
		if (mode == MODE_LDM) { SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE } <= CMD_LOAD_MODE;
		else if (mode == MODE_PRE) { SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE } <= CMD_PRECHARGE;
	end

	SDRAM_A <= 13'd0;
	if (mode == MODE_NORMAL && ram_req) begin
		if (q == STATE_START) SDRAM_A <= a[21:9];
		else if (q == STATE_CONT) SDRAM_A <= { 2'b00, 2'b10, a[22], a[8:1] };   // auto precharge
	end
	else if (q == STATE_START) begin
		if (mode == MODE_LDM) SDRAM_A <= MODE;
		else if (mode == MODE_PRE) SDRAM_A <= 13'b0010000000000;
	end

	if (q == STATE_START) SDRAM_BA <= mode == MODE_NORMAL ? bank : 2'b00;

	dq_oe <= q == STATE_CONT && ram_req && wr && mode == MODE_NORMAL;
	dq_out <= data;
	if (q == STATE_READY && !wr && ram_req) sd_dat <= SDRAM_DQ;
end

endmodule
