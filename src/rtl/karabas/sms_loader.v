`timescale 1ns / 1ps
`default_nettype wire
/*
 sms_loader.v

 The cartridge: the bytes of the file loader of kg_mcu2 (LD kind 1: a .sms / .gg / .sg / .sc file)
 into the SDRAM from word 0 as 16-bit words (little endian: the even byte low), one write per odd
 byte through the toggle port of sms_sdram (we / we_ack; a byte comes every 250 ns at most, a write
 takes 23 clocks = 425 ns at most, two bytes are 500 ns). A file of odd size gets its last byte
 written with FF above it.

 As the MiST top of SMS_MiSTer: cart_mask = the OR of all byte addresses of the file (the ROM is
 mirrored over the next power of two), romhdr = the file has a 512-byte copier header (its last
 address ends in 1FF: the reads then go 512 bytes further).

 The system from the extension of the file (LD_EXT, ASCII, byte 0 = the first character):
   gg = .gg (Game Gear), sg = .sg (SG-1000), sc = .sc (SC-3000); anything else is a Master System
   cartridge. Taken when the file has come: kg_l2_load raises ld_active before the bytes of the
   extension (START bytes 10..17) are in.

 cart_ready from the end of the first file on; loading while a file comes (the top holds the machine
 in reset meanwhile).
*/
module sms_loader (
	input  wire        clk,

	input  wire        file_active,
	input  wire        file_wr,
	input  wire [31:0] file_addr,
	input  wire [7:0]  file_data,
	input  wire [63:0] file_ext,

	output reg  [23:0] sdr_waddr = 24'd0,
	output reg  [15:0] sdr_din = 16'd0,
	output reg         sdr_we = 1'b0,      // toggles for a write

	output reg  [21:0] cart_mask = 22'd0,
	output reg         romhdr = 1'b0,
	output reg         gg = 1'b0,
	output reg         sg = 1'b0,
	output reg         sc = 1'b0,

	output reg         loading = 1'b0,
	output reg         cart_ready = 1'b0
);

reg [7:0]  lo = 8'd0;
reg        odd = 1'b0;          // a low byte waits for its high byte
reg [21:0] last = 22'd0;
reg        active_d = 1'b0;

// the extension, lower case
function [7:0] lc(input [7:0] c);
	lc = (c >= 8'h41 && c <= 8'h5A) ? c + 8'h20 : c;
endfunction
wire [7:0] e0 = lc(file_ext[7:0]), e1 = lc(file_ext[15:8]), e2 = file_ext[23:16];

always @(posedge clk) begin
	active_d <= file_active;
	loading <= file_active;

	if (file_active && !active_d) begin
		cart_mask <= 22'd0;
		odd <= 1'b0;
	end

	if (file_wr) begin
		cart_mask <= cart_mask | file_addr[21:0];
		last <= file_addr[21:0];
		if (!file_addr[0]) begin
			lo <= file_data;
			odd <= 1'b1;
		end
		else begin
			odd <= 1'b0;
			sdr_waddr <= file_addr[24:1];
			sdr_din <= { file_data, lo };
			sdr_we <= ~sdr_we;
		end
	end

	if (!file_active && active_d) begin
		cart_ready <= 1'b1;
		romhdr <= last[9:0] == 10'h1FF;
		gg <= e0 == "g" && e1 == "g" && e2 == 8'd0;
		sg <= e0 == "s" && e1 == "g" && e2 == 8'd0;
		sc <= e0 == "s" && e1 == "c" && e2 == 8'd0;
		if (odd) begin
			sdr_waddr <= { 2'b00, last[21:1] };
			sdr_din <= { 8'hFF, lo };
			sdr_we <= ~sdr_we;
		end
	end
end

endmodule
