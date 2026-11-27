`timescale 1ps / 1ps
`default_nettype wire

/*
 tb_fb.v - sms_fb on an asynchronous SRAM model (10 ns) with a synthetic VDP as the SMS machine gives
 it: lines of 3420 MCLK, W pixels on CE_PIX every 10 MCLK, H lines of 262; the colour comes one
 CE_PIX after the hbl / vbl of its pixel (as sms_machine). W x H = 256 x 192 by default (+w=N +h=N:
 256 x 224, 160 x 144 ...). The pixel of (x, y) is { x[3:0], y[3:0], x[7:4] ^ y[7:4] }. Checked in
 output frame 3: every pixel of 1024 x 768 is the source pixel (k / S, oy / S) inside the picture
 (X0 + k, y0 + oy), S the largest of 5..2 that fits, and black outside.

 iverilog -o build/tb_fb tb_fb.v ../rtl/karabas/sms_fb.v ../../modules/rtl/mem/kg_sdpram.v
 vvp build/tb_fb [+w=N] [+h=N]
*/

module tb_fb;

reg clk = 0, clk_65 = 0;
always #9231 clk = ~clk;        // 54.166 MHz
always #7692 clk_65 = ~clk_65;  // 65.0 MHz

integer W, PIXDIV, H, S;
initial begin
	W = 256; PIXDIV = 10; H = 192;
	if ($value$plusargs("w=%d", W)) ;
	if ($value$plusargs("h=%d", H)) ;
	S = (5 * W <= 1024 && 5 * H <= 768) ? 5 : (4 * W <= 1024 && 4 * H <= 768) ? 4 :
	    (3 * W <= 1024 && 3 * H <= 768) ? 3 : 2;
end

// ------------------------------------------------------------------ synthetic VDP
reg [3:0] r = 0, g = 0, b = 0;
reg hbl = 1, vbl = 1, ce_pix = 0;
integer hc = 0, vc = 0, px = 0;
always @(posedge clk) begin
	hc <= hc == 3419 ? 0 : hc + 1;
	if (hc == 3419) vc <= vc == (H > 256 ? 312 : 261) ? 0 : vc + 1;
	ce_pix <= (hc % PIXDIV) == 0;
	// active area: from MCLK 200, W pixels; the colour one pixel (PIXDIV clocks) after its blanking
	hbl <= !(hc >= 200 && hc < 200 + W * PIXDIV);
	vbl <= !(vc >= 3 && vc < 3 + H);
	px = (hc - 200 - PIXDIV) / PIXDIV;
	{ r, g, b } <= (hc >= 200 + PIXDIV) ? src(px, vc - 3) : 12'hF0F;
end
// the expected pixel of source (x, y)
function [11:0] src;
	input integer x, y;
	reg [7:0] xx, yy;
	begin
		xx = x; yy = y;
		src = { xx[3:0], yy[3:0], xx[7:4] ^ yy[7:4] };
	end
endfunction

// ------------------------------------------------------------------ SRAM model
wire [20:0] MA;
wire [15:0] MD;
wire [1:0] MWR_N, MRD_N;
reg [15:0] mem [0:(1 << 21) - 1];
reg [15:0] rd_q;
always @(MA, MRD_N, MWR_N) rd_q <= #10000 mem[MA];
assign MD = (MRD_N == 2'b00 && MWR_N == 2'b11) ? rd_q : 16'bz;
always @(posedge MWR_N[0]) mem[MA][7:0] <= MD[7:0];
always @(posedge MWR_N[1]) mem[MA][15:8] <= MD[15:8];

// ------------------------------------------------------------------ dut
wire [23:0] rgb;
wire hs, vs, de;
sms_fb dut (
	.clk(clk), .r(r), .g(g), .b(b), .hbl(hbl), .vbl(vbl), .ce_pix(ce_pix),
	.MA(MA), .MD(MD), .MWR_N(MWR_N), .MRD_N(MRD_N),
	.clk_65(clk_65), .rgb(rgb), .hs(hs), .vs(vs), .de(de)
);

// ------------------------------------------------------------------ check
integer oframe = 0, ox = 0, oy = 0, lines = 0, errors = 0, checked = 0, k, sy, y0, XW;
reg vs_d = 0, de_d = 0, hs_d = 0;
reg [11:0] exp_px;
always @(posedge clk_65) begin
	vs_d <= vs; de_d <= de; hs_d <= hs;
	if (vs && !vs_d) begin
		if (oframe == 3) begin
			if (oy != 768) begin $display("FAIL: %0d picture lines", oy); errors = errors + 1; end
			$display("tb_fb: %0d x %0d (x %0d), %0d pixels checked, %0d errors", W, H, S, checked, errors);
			if (errors) $display("FAIL"); else $display("PASS");
			$finish;
		end
		oframe = oframe + 1;
		oy = 0;
	end
	if (de) begin
		if (oframe == 3) begin
			XW = S * W;
			y0 = (768 - S * H) / 2;
			k = ox - (1024 - XW) / 2;
			if (oy >= y0 && oy < y0 + S * H && k >= 0 && k < XW) begin
				sy = (oy - y0) / S;
				exp_px = src(k / S, sy);
				if (rgb != { exp_px[11:8], exp_px[11:8], exp_px[7:4], exp_px[7:4], exp_px[3:0], exp_px[3:0] }) begin
					if (errors < 10) $display("FAIL: out %0d,%0d = %06x, expected source %0d,%0d = %03x", ox, oy, rgb, k / S, sy, exp_px);
					errors = errors + 1;
				end
			end
			else if (rgb != 24'd0) begin
				if (errors < 10) $display("FAIL: out %0d,%0d = %06x outside the picture", ox, oy, rgb);
				errors = errors + 1;
			end
			checked = checked + 1;
		end
		ox = ox + 1;
	end
	if (!de && de_d) begin
		if (ox != 1024 && oframe == 3) begin $display("FAIL: line %0d has %0d pixels", oy, ox); errors = errors + 1; end
		ox = 0;
		oy = oy + 1;
	end
end

initial begin
	#200000000000;
	$display("FAIL: timeout"); $finish;
end

endmodule
