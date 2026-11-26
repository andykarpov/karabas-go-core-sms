module SEGASYS1_PRGDEC (
	clk,
	mrom_m1,
	mrom_ad,
	mrom_dt,
	rad,
	rdt,
	ROMCL,
	ROMAD,
	ROMDT,
	ROMEN
);
	input clk;
	input mrom_m1;
	input [14:0] mrom_ad;
	output wire [7:0] mrom_dt;
	output wire [14:0] rad;
	input [7:0] rdt;
	input ROMCL;
	input [24:0] ROMAD;
	input [7:0] ROMDT;
	input ROMEN;
	wire [7:0] od0;
	wire [7:0] od1;
	wire [14:0] dum;
	SEGASYS1_DECT1 t1(
		.clk(clk),
		.mrom_m1(mrom_m1),
		.mrom_ad(mrom_ad),
		.mrom_dt(od0),
		.rad(rad),
		.rdt(rdt),
		.ROMCL(ROMCL),
		.ROMAD(ROMAD),
		.ROMDT(ROMDT),
		.ROMEN(ROMEN)
	);
	SEGASYS1_DECT2 t2(
		.clk(clk),
		.mrom_m1(mrom_m1),
		.mrom_ad(mrom_ad),
		.mrom_dt(od1),
		.rad(dum),
		.rdt(rdt),
		.ROMCL(ROMCL),
		.ROMAD(ROMAD),
		.ROMDT(ROMDT),
		.ROMEN(ROMEN)
	);
	reg [15:0] cnt0;
	reg [15:0] cnt2;
	always @(posedge ROMCL)
		if (ROMEN) begin
			if (ROMAD >= 25'h0058400) begin
				cnt2 <= (ROMDT >= 8'd24 ? 16'd0 : cnt2 + 1'd1);
				cnt0 <= (ROMDT != 8'd0 ? 16'd0 : cnt0 + 1'd1);
			end
			else begin
				cnt2 <= 0;
				cnt0 <= 0;
			end
		end
	assign mrom_dt = (cnt0 >= 128 ? rdt : (cnt2 >= 128 ? od1 : od0));
endmodule
module SEGASYS1_DECT1 (
	clk,
	mrom_m1,
	mrom_ad,
	mrom_dt,
	rad,
	rdt,
	ROMCL,
	ROMAD,
	ROMDT,
	ROMEN
);
	input clk;
	input mrom_m1;
	input [14:0] mrom_ad;
	output reg [7:0] mrom_dt;
	output wire [14:0] rad;
	input [7:0] rdt;
	input ROMCL;
	input [24:0] ROMAD;
	input [7:0] ROMDT;
	input ROMEN;
	reg [15:0] madr;
	wire [7:0] mdat = rdt;
	wire f = mdat[7];
	wire [7:0] xorv = {f, 1'b0, f, 1'b0, f, 3'b000};
	wire [7:0] andv = ~8'ha8;
	wire [1:0] decidx0 = {mdat[5], mdat[3]} ^ {f, f};
	wire [6:0] decidx = {madr[12], madr[8], madr[4], madr[0], ~madr[15], decidx0};
	wire [7:0] dectbl;
	wire [7:0] mdec = (mdat & andv) | (dectbl ^ xorv);
	DLROM #(
		7,
		8
	) dect(
		clk,
		decidx,
		dectbl,
		ROMCL,
		ROMAD,
		ROMDT,
		ROMEN & (ROMAD[18:7] == 12'b101100001000)
	);
	reg phase = 1'b0;
	always @(posedge clk) begin
		if (phase)
			mrom_dt <= mdec;
		else
			madr <= {mrom_m1, mrom_ad};
		phase <= ~phase;
	end
	assign rad = madr[14:0];
endmodule
module SEGASYS1_DECT2 (
	clk,
	mrom_m1,
	mrom_ad,
	mrom_dt,
	rad,
	rdt,
	ROMCL,
	ROMAD,
	ROMDT,
	ROMEN
);
	input clk;
	input mrom_m1;
	input [14:0] mrom_ad;
	output reg [7:0] mrom_dt;
	output wire [14:0] rad;
	input [7:0] rdt;
	input ROMCL;
	input [24:0] ROMAD;
	input [7:0] ROMDT;
	input ROMEN;
	function [7:0] bswp;
		input [4:0] m;
		input [7:0] v;
		case (m)
			0: bswp = {v[7], v[6], v[5], v[4], v[3], v[2], v[1], v[0]};
			1: bswp = {v[7], v[4], v[5], v[6], v[3], v[2], v[1], v[0]};
			2: bswp = {v[7], v[2], v[5], v[4], v[3], v[6], v[1], v[0]};
			3: bswp = {v[7], v[0], v[5], v[4], v[3], v[2], v[1], v[6]};
			4: bswp = {v[7], v[6], v[5], v[2], v[3], v[4], v[1], v[0]};
			5: bswp = {v[7], v[6], v[5], v[0], v[3], v[2], v[1], v[4]};
			6: bswp = {v[7], v[6], v[5], v[4], v[3], v[0], v[1], v[2]};
			7: bswp = {v[7], v[2], v[5], v[6], v[3], v[4], v[1], v[0]};
			8: bswp = {v[7], v[4], v[5], v[2], v[3], v[6], v[1], v[0]};
			9: bswp = {v[7], v[4], v[5], v[6], v[3], v[0], v[1], v[2]};
			10: bswp = {v[7], v[6], v[5], v[0], v[3], v[4], v[1], v[2]};
			11: bswp = {v[7], v[0], v[5], v[6], v[3], v[4], v[1], v[2]};
			12: bswp = {v[7], v[4], v[5], v[0], v[3], v[6], v[1], v[2]};
			13: bswp = {v[7], v[0], v[5], v[4], v[3], v[6], v[1], v[2]};
			14: bswp = {v[7], v[6], v[5], v[2], v[3], v[0], v[1], v[4]};
			15: bswp = {v[7], v[2], v[5], v[6], v[3], v[0], v[1], v[4]};
			16: bswp = {v[7], v[0], v[5], v[6], v[3], v[2], v[1], v[4]};
			17: bswp = {v[7], v[2], v[5], v[0], v[3], v[6], v[1], v[4]};
			18: bswp = {v[7], v[0], v[5], v[2], v[3], v[6], v[1], v[4]};
			19: bswp = {v[7], v[4], v[5], v[2], v[3], v[0], v[1], v[6]};
			20: bswp = {v[7], v[2], v[5], v[4], v[3], v[0], v[1], v[6]};
			21: bswp = {v[7], v[4], v[5], v[0], v[3], v[2], v[1], v[6]};
			22: bswp = {v[7], v[2], v[5], v[0], v[3], v[4], v[1], v[6]};
			23: bswp = {v[7], v[0], v[5], v[2], v[3], v[4], v[1], v[6]};
			default: bswp = 0;
		endcase
	endfunction
	reg [15:0] madr;
	wire [7:0] sd;
	wire [7:0] xd;
	wire [6:0] ix = {madr[14], madr[12], madr[9], madr[6], madr[3], madr[0], ~madr[15]};
	DLROM #(
		7,
		8
	) xort(
		clk,
		ix,
		xd,
		ROMCL,
		ROMAD,
		ROMDT,
		ROMEN & (ROMAD[18:7] == 12'b100100000000)
	);
	DLROM #(
		7,
		8
	) swpt(
		clk,
		ix,
		sd,
		ROMCL,
		ROMAD,
		ROMDT,
		ROMEN & (ROMAD[18:7] == 12'b100100000001)
	);
	reg phase = 1'b0;
	always @(posedge clk) begin
		if (phase)
			mrom_dt <= bswp(sd, rdt) ^ xd;
		else
			madr <= {mrom_m1, mrom_ad};
		phase <= ~phase;
	end
	assign rad = madr[14:0];
endmodule
