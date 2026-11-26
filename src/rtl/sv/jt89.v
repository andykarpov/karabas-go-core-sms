module jt89 (
	clk,
	clk_en,
	rst,
	wr_n,
	din,
	mux,
	soundL,
	soundR,
	ready,
	ss_out,
	ss_set,
	ss_in,
	ss_ext_out,
	ss_ext_in,
	ss_ext_set,
	ss_div_out,
	ss_div_in,
	ss_quiescent
);
	input clk;
	(* direct_enable = 1 *) input clk_en;
	input rst;
	input wr_n;
	input [7:0] din;
	input [7:0] mux;
	output wire signed [10:0] soundL;
	output wire signed [10:0] soundR;
	output wire ready;
	output wire [55:0] ss_out;
	input ss_set;
	input [55:0] ss_in;
	output wire [95:0] ss_ext_out;
	input [95:0] ss_ext_in;
	input ss_ext_set;
	output wire [3:0] ss_div_out;
	input [3:0] ss_div_in;
	output wire ss_quiescent;
	wire signed [8:0] ch0;
	wire signed [8:0] ch1;
	wire signed [8:0] ch2;
	wire signed [8:0] noise;
	assign ready = 1'b1;
	reg cen_16; // karabas: declared before its use in jt89_mixer (XST)
	jt89_mixer mix(
		.clk(clk),
		.clk_en(clk_en),
		.cen_16(cen_16),
		.rst(rst),
		.ch0(ch0),
		.ch1(ch1),
		.ch2(ch2),
		.noise(noise),
		.mux(mux),
		.soundL(soundL),
		.soundR(soundR)
	);
	reg [9:0] tone0;
	reg [9:0] tone1;
	reg [9:0] tone2;
	reg [3:0] vol0;
	reg [3:0] vol1;
	reg [3:0] vol2;
	reg [3:0] vol3;
	reg [2:0] ctrl3;
	reg [2:0] regn;
	reg [3:0] clk_div;
	always @(negedge clk)
		if (rst)
			cen_16 <= 1'b1;
		else
			cen_16 <= !ss_ext_set && (clk_en & (&clk_div));
	always @(posedge clk)
		if (rst)
			clk_div <= 4'd0;
		else if (ss_ext_set)
			clk_div <= ss_div_in;
		else if (clk_en)
			clk_div <= clk_div + 1'b1;
	assign ss_out = {regn, ctrl3, vol3, vol2, vol1, vol0, tone2, tone1, tone0};
	assign ss_div_out = clk_div;
	reg clr_noise;
	reg last_wr;
	assign ss_quiescent = (((!clk_en && !cen_16) && wr_n) && !clr_noise) && last_wr;
	wire [2:0] reg_sel = (din[7] ? din[6:4] : regn);
	always @(posedge clk)
		if (rst) begin
			{vol0, vol1, vol2, vol3} <= {16 {1'b1}};
			{tone0, tone1, tone2} <= 30'd0;
			ctrl3 <= 3'b100;
			regn <= 3'd0;
		end
		else if (ss_set || ss_ext_set) begin
			tone0 <= ss_in[9:0];
			tone1 <= ss_in[19:10];
			tone2 <= ss_in[29:20];
			vol0 <= ss_in[33:30];
			vol1 <= ss_in[37:34];
			vol2 <= ss_in[41:38];
			vol3 <= ss_in[45:42];
			ctrl3 <= ss_in[48:46];
			regn <= ss_in[51:49];
			if (ss_ext_set) begin
				clr_noise <= 1'b0;
				last_wr <= 1'b1;
			end
		end
		else begin
			last_wr <= wr_n;
			if (!wr_n && last_wr) begin
				clr_noise <= din[7:4] == 4'b1110;
				regn <= reg_sel;
				case (reg_sel)
					3'b000:
						if (din[7])
							tone0[3:0] <= din[3:0];
						else
							tone0[9:4] <= din[5:0];
					3'b010:
						if (din[7])
							tone1[3:0] <= din[3:0];
						else
							tone1[9:4] <= din[5:0];
					3'b100:
						if (din[7])
							tone2[3:0] <= din[3:0];
						else
							tone2[9:4] <= din[5:0];
					3'b110: ctrl3 <= din[2:0];
					3'b001: vol0 <= din[3:0];
					3'b011: vol1 <= din[3:0];
					3'b101: vol2 <= din[3:0];
					3'b111: vol3 <= din[3:0];
				endcase
			end
			else
				clr_noise <= 1'b0;
		end
	jt89_tone u_tone0(
		.clk(clk),
		.rst(rst),
		.clk_en(cen_16),
		.vol(vol0),
		.tone(tone0),
		.snd(ch0),
		.out(),
		.ss_out({ss_ext_out[68:60], ss_ext_out[10:0]}),
		.ss_set(ss_ext_set),
		.ss_in({ss_ext_in[68:60], ss_ext_in[10:0]})
	);
	jt89_tone u_tone1(
		.clk(clk),
		.rst(rst),
		.clk_en(cen_16),
		.vol(vol1),
		.tone(tone1),
		.snd(ch1),
		.out(),
		.ss_out({ss_ext_out[77:69], ss_ext_out[21:11]}),
		.ss_set(ss_ext_set),
		.ss_in({ss_ext_in[77:69], ss_ext_in[21:11]})
	);
	wire out2;
	jt89_tone u_tone2(
		.clk(clk),
		.rst(rst),
		.clk_en(cen_16),
		.vol(vol2),
		.tone(tone2),
		.snd(ch2),
		.out(out2),
		.ss_out({ss_ext_out[86:78], ss_ext_out[32:22]}),
		.ss_set(ss_ext_set),
		.ss_in({ss_ext_in[86:78], ss_ext_in[32:22]})
	);
	jt89_noise u_noise(
		.clk(clk),
		.rst(rst),
		.clk_en(cen_16),
		.clr(clr_noise),
		.vol(vol3),
		.ctrl3(ctrl3),
		.tone2(tone2),
		.snd(noise),
		.ss_out({ss_ext_out[95:87], ss_ext_out[59:33]}),
		.ss_set(ss_ext_set),
		.ss_in({ss_ext_in[95:87], ss_ext_in[59:33]})
	);
endmodule
module jt89_tone (
	clk,
	clk_en,
	rst,
	tone,
	vol,
	snd,
	out,
	ss_out,
	ss_set,
	ss_in
);
	input clk;
	(* direct_enable = 1 *) input clk_en;
	input rst;
	input [9:0] tone;
	input [3:0] vol;
	output wire [8:0] snd;
	output reg out;
	output wire [19:0] ss_out;
	input ss_set;
	input [19:0] ss_in;
	reg [9:0] cnt;
	reg last_out;
	assign ss_out[10:0] = {out, cnt};
	jt89_vol u_vol(
		.rst(rst),
		.clk(clk),
		.clk_en(clk_en),
		.din(out),
		.vol(vol),
		.snd(snd),
		.ss_out(ss_out[19:11]),
		.ss_set(ss_set),
		.ss_in(ss_in[19:11])
	);
	always @(posedge clk)
		if (rst) begin
			cnt <= 10'd0;
			out <= 1'b0;
		end
		else if (ss_set) begin
			cnt <= ss_in[9:0];
			out <= ss_in[10];
		end
		else if (clk_en) begin
			if (tone < 6)
				out <= 1'b1;
			else if (cnt[9:0] == 10'd1) begin
				cnt[9:0] <= (tone == 10'd0 ? 10'd1 : tone);
				out <= ~out;
			end
			else
				cnt <= cnt - 10'b0000000001;
		end
endmodule
module jt89_noise (
	clk,
	clk_en,
	rst,
	clr,
	ctrl3,
	vol,
	tone2,
	snd,
	ss_out,
	ss_set,
	ss_in
);
	input clk;
	(* direct_enable = 1 *) input clk_en;
	input rst;
	input clr;
	input [2:0] ctrl3;
	input [3:0] vol;
	input [9:0] tone2;
	output wire [8:0] snd;
	output wire [35:0] ss_out;
	input ss_set;
	input [35:0] ss_in;
	reg [15:0] shift;
	reg [10:0] cnt;
	reg update;
	jt89_vol u_vol(
		.rst(rst),
		.clk(clk),
		.clk_en(clk_en),
		.din(shift[0]),
		.vol(vol),
		.snd(snd),
		.ss_out(ss_out[35:27]),
		.ss_set(ss_set),
		.ss_in(ss_in[35:27])
	);
	reg v;
	assign ss_out[26:0] = {shift, cnt};
	always @(posedge clk)
		if (rst)
			cnt <= 11'd0;
		else if (ss_set)
			cnt <= ss_in[10:0];
		else if (clk_en) begin
			if (cnt == 11'd1)
				case (ctrl3[1:0])
					2'd0: cnt <= 11'h020;
					2'd1: cnt <= 11'h040;
					2'd2: cnt <= 11'h080;
					2'd3: cnt <= (tone2 == 11'd0 ? 11'h002 : {tone2, 1'b0});
				endcase
			else
				cnt <= cnt - 11'b00000000001;
		end
	wire fb = (ctrl3[2] ? shift[0] ^ shift[3] : shift[0]);
	always @(posedge clk)
		if (rst)
			shift <= 16'h8000;
		else if (ss_set)
			shift <= ss_in[26:11];
		else if (clr)
			shift <= 16'h8000;
		else if (clk_en) begin
			if (cnt == 11'd1)
				shift <= (|shift == 1'b0 ? 16'h8000 : {fb, shift[15:1]});
		end
endmodule
module jt89_vol (
	clk,
	clk_en,
	rst,
	din,
	vol,
	snd,
	ss_out,
	ss_set,
	ss_in
);
	input clk;
	input clk_en;
	input rst;
	input din;
	input [3:0] vol;
	output reg signed [8:0] snd;
	output wire [8:0] ss_out;
	input ss_set;
	input [8:0] ss_in;
	reg [7:0] max;
	assign ss_out = snd;
	always @(*)
		case (vol)
			4'd0: max = 8'd255;
			4'd1: max = 8'd203;
			4'd2: max = 8'd161;
			4'd3: max = 8'd128;
			4'd4: max = 8'd102;
			4'd5: max = 8'd81;
			4'd6: max = 8'd64;
			4'd7: max = 8'd51;
			4'd8: max = 8'd40;
			4'd9: max = 8'd32;
			4'd10: max = 8'd26;
			4'd11: max = 8'd20;
			4'd12: max = 8'd16;
			4'd13: max = 8'd13;
			4'd14: max = 8'd10;
			4'd15: max = 8'd0;
		endcase
	always @(posedge clk)
		if (rst)
			snd <= 9'd0;
		else if (ss_set)
			snd <= ss_in;
		else if (clk_en)
			snd <= (din ? {1'b0, max} : -{1'b0, max});
endmodule
module jt89_mixer (
	rst,
	clk,
	clk_en,
	cen_16,
	ch0,
	ch1,
	ch2,
	noise,
	mux,
	soundL,
	soundR
);
	parameter bw = 9;
	input rst;
	input clk;
	input clk_en;
	input cen_16;
	input [bw - 1:0] ch0;
	input [bw - 1:0] ch1;
	input [bw - 1:0] ch2;
	input [bw - 1:0] noise;
	input [7:0] mux;
	output reg signed [bw + 1:0] soundL;
	output reg signed [bw + 1:0] soundR;
	reg signed [bw + 1:0] freshR;
	reg signed [bw + 1:0] freshL;
	always @(*) freshR = (((mux[0] ? {{2 {ch0[bw - 1]}}, ch0} : {bw + 1 {1'b0}}) + (mux[1] ? {{2 {ch1[bw - 1]}}, ch1} : {bw + 1 {1'b0}})) + (mux[2] ? {{2 {ch2[bw - 1]}}, ch2} : {bw + 1 {1'b0}})) + (mux[3] ? {{2 {noise[bw - 1]}}, noise} : {bw + 1 {1'b0}});
	always @(posedge clk) soundR <= freshR;
	always @(*) freshL = (((mux[4] ? {{2 {ch0[bw - 1]}}, ch0} : {bw + 1 {1'b0}}) + (mux[5] ? {{2 {ch1[bw - 1]}}, ch1} : {bw + 1 {1'b0}})) + (mux[6] ? {{2 {ch2[bw - 1]}}, ch2} : {bw + 1 {1'b0}})) + (mux[7] ? {{2 {noise[bw - 1]}}, noise} : {bw + 1 {1'b0}});
	always @(posedge clk) soundL <= freshL;
endmodule
