module DLROM (
	CL0,
	AD0,
	DO0,
	CL1,
	AD1,
	DI1,
	WE1
);
	parameter AW = 0;
	parameter DW = 0;
	input CL0;
	input [AW - 1:0] AD0;
	output reg [DW - 1:0] DO0;
	input CL1;
	input [AW - 1:0] AD1;
	input [DW - 1:0] DI1;
	input WE1;
	reg [DW - 1:0] core [0:(2 ** AW) - 1];
	always @(posedge CL0) DO0 <= core[AD0];
	always @(posedge CL1)
		if (WE1)
			core[AD1] <= DI1;
endmodule
module SRAM_2048 (
	CL,
	ADRS,
	OUT,
	WR,
	IN
);
	input CL;
	input [10:0] ADRS;
	output reg [7:0] OUT;
	input WR;
	input [7:0] IN;
	reg [7:0] ramcore [0:2047];
	always @(posedge CL)
		if (WR)
			ramcore[ADRS] <= IN;
		else
			OUT <= ramcore[ADRS];
endmodule
module DPRAM2048 (
	clk0,
	adr0,
	dat0,
	wen0,
	clk1,
	adr1,
	dat1,
	dtr0
);
	input clk0;
	input [10:0] adr0;
	input [7:0] dat0;
	input wen0;
	input clk1;
	input [10:0] adr1;
	output reg [7:0] dat1;
	output reg [7:0] dtr0;
	reg [7:0] core [0:2047];
	always @(posedge clk0)
		if (wen0)
			core[adr0] <= dat0;
		else
			dtr0 <= core[adr0];
	always @(posedge clk1) dat1 <= core[adr1];
endmodule
module DPRAM1024 (
	clk0,
	adr0,
	dat0,
	wen0,
	clk1,
	adr1,
	dat1,
	dtr0
);
	input clk0;
	input [9:0] adr0;
	input [7:0] dat0;
	input wen0;
	input clk1;
	input [9:0] adr1;
	output reg [7:0] dat1;
	output reg [7:0] dtr0;
	reg [7:0] core [0:1023];
	always @(posedge clk0)
		if (wen0)
			core[adr0] <= dat0;
		else
			dtr0 <= core[adr0];
	always @(posedge clk1) dat1 <= core[adr1];
endmodule
module DPRAM2048_8_16 (
	clk0,
	adr0,
	dat0,
	wen0,
	clk1,
	adr1,
	dat1,
	dtr0
);
	input clk0;
	input [10:0] adr0;
	input [7:0] dat0;
	input wen0;
	input clk1;
	input [9:0] adr1;
	output wire [15:0] dat1;
	output wire [7:0] dtr0;
	wire [7:0] do0;
	wire [7:0] do1;
	wire [7:0] doH;
	wire [7:0] doL;
	DPRAM1024 core0(
		.clk0(clk0),
		.adr0(adr0[10:1]),
		.dat0(dat0),
		.wen0(wen0 & ~adr0[0]),
		.clk1(clk1),
		.adr1(adr1),
		.dat1(doL),
		.dtr0(do0)
	);
	DPRAM1024 core1(
		.clk0(clk0),
		.adr0(adr0[10:1]),
		.dat0(dat0),
		.wen0(wen0 & adr0[0]),
		.clk1(clk1),
		.adr1(adr1),
		.dat1(doH),
		.dtr0(do1)
	);
	assign dtr0 = (adr0[0] ? do1 : do0);
	assign dat1 = {doH, doL};
endmodule
module VRAMs (
	clk0,
	adr0,
	dat0,
	dtw0,
	wen0,
	clk1,
	adr1,
	dat1
);
	input clk0;
	input [9:0] adr0;
	output reg [7:0] dat0;
	input [7:0] dtw0;
	input wen0;
	input clk1;
	input [9:0] adr1;
	output reg [7:0] dat1;
	reg [7:0] core [0:1023];
	always @(posedge clk0)
		if (wen0)
			core[adr0] <= dtw0;
		else
			dat0 <= core[adr0];
	always @(posedge clk1) dat1 <= core[adr1];
endmodule
module VRAM (
	clk0,
	adr0,
	dat0,
	dtw0,
	wen0,
	clk1,
	adr1,
	dat1
);
	input clk0;
	input [10:0] adr0;
	output wire [7:0] dat0;
	input [7:0] dtw0;
	input wen0;
	input clk1;
	input [9:0] adr1;
	output wire [15:0] dat1;
	wire even = ~adr0[0];
	wire odd = adr0[0];
	wire [7:0] do00;
	wire [7:0] do01;
	wire [7:0] do10;
	wire [7:0] do11;
	VRAMs ram0(
		.clk0(clk0),
		.adr0(adr0[10:1]),
		.dat0(do00),
		.dtw0(dtw0),
		.wen0(wen0 & even),
		.clk1(clk1),
		.adr1(adr1),
		.dat1(do10)
	);
	VRAMs ram1(
		.clk0(clk0),
		.adr0(adr0[10:1]),
		.dat0(do01),
		.dtw0(dtw0),
		.wen0(wen0 & odd),
		.clk1(clk1),
		.adr1(adr1),
		.dat1(do11)
	);
	assign dat0 = (adr0[0] ? do01 : do00);
	assign dat1 = {do11, do10};
endmodule
module LineBuf (
	clkr,
	radr,
	clre,
	rdat,
	clkw,
	wadr,
	wdat,
	we,
	rdat1
);
	input clkr;
	input [9:0] radr;
	input clre;
	output reg [10:0] rdat;
	input clkw;
	input [9:0] wadr;
	input [10:0] wdat;
	input we;
	output reg [10:0] rdat1;
	reg [10:0] ram [0:1023];
	always @(posedge clkr)
		if (clre) begin
			ram[radr] <= 0;
			rdat <= 0;
		end
		else
			rdat <= ram[radr];
	always @(posedge clkw)
		if (we) begin
			ram[wadr] <= wdat;
			rdat1 <= wdat;
		end
		else
			rdat1 <= ram[wadr];
endmodule
module dataselector1_32 (
	oDATA,
	iSEL0,
	iDATA0,
	dData
);
	output wire [31:0] oDATA;
	input iSEL0;
	input [31:0] iDATA0;
	input [31:0] dData;
	assign oDATA = (iSEL0 ? iDATA0 : dData);
endmodule
module dataselector3 (
	oDATA,
	iSEL0,
	iDATA0,
	iSEL1,
	iDATA1,
	iSEL2,
	iDATA2,
	dData
);
	output wire [7:0] oDATA;
	input iSEL0;
	input [7:0] iDATA0;
	input iSEL1;
	input [7:0] iDATA1;
	input iSEL2;
	input [7:0] iDATA2;
	input [7:0] dData;
	assign oDATA = (iSEL0 ? iDATA0 : (iSEL1 ? iDATA1 : (iSEL2 ? iDATA2 : dData)));
endmodule
module dataselector2_11 (
	oDATA,
	iSEL0,
	iDATA0,
	iSEL1,
	iDATA1,
	dData
);
	output wire [10:0] oDATA;
	input iSEL0;
	input [10:0] iDATA0;
	input iSEL1;
	input [10:0] iDATA1;
	input [10:0] dData;
	assign oDATA = (iSEL0 ? iDATA0 : (iSEL1 ? iDATA1 : dData));
endmodule
module dataselector5 (
	oDATA,
	iSEL0,
	iDATA0,
	iSEL1,
	iDATA1,
	iSEL2,
	iDATA2,
	iSEL3,
	iDATA3,
	iSEL4,
	iDATA4,
	dData
);
	output wire [7:0] oDATA;
	input iSEL0;
	input [7:0] iDATA0;
	input iSEL1;
	input [7:0] iDATA1;
	input iSEL2;
	input [7:0] iDATA2;
	input iSEL3;
	input [7:0] iDATA3;
	input iSEL4;
	input [7:0] iDATA4;
	input [7:0] dData;
	assign oDATA = (iSEL0 ? iDATA0 : (iSEL1 ? iDATA1 : (iSEL2 ? iDATA2 : (iSEL3 ? iDATA3 : (iSEL4 ? iDATA4 : dData)))));
endmodule
module dataselector6 (
	oDATA,
	iSEL0,
	iDATA0,
	iSEL1,
	iDATA1,
	iSEL2,
	iDATA2,
	iSEL3,
	iDATA3,
	iSEL4,
	iDATA4,
	iSEL5,
	iDATA5,
	dData
);
	output wire [7:0] oDATA;
	input iSEL0;
	input [7:0] iDATA0;
	input iSEL1;
	input [7:0] iDATA1;
	input iSEL2;
	input [7:0] iDATA2;
	input iSEL3;
	input [7:0] iDATA3;
	input iSEL4;
	input [7:0] iDATA4;
	input iSEL5;
	input [7:0] iDATA5;
	input [7:0] dData;
	assign oDATA = (iSEL0 ? iDATA0 : (iSEL1 ? iDATA1 : (iSEL2 ? iDATA2 : (iSEL3 ? iDATA3 : (iSEL4 ? iDATA4 : (iSEL5 ? iDATA5 : dData))))));
endmodule
