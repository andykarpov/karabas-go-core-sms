`timescale 1ns / 1ps
`default_nettype wire

/*
 sms_sk1100.v

 The SK-1100 keyboard of the SC-3000 (and of the SG-1000 with the keyboard) from the USB keyboard:
 the matrix of keyboard.sv of SMS_MiSTer (there from PS/2 set 2 codes), here from the HID boot
 report of kg_mcu2 (the modifiers byte and the 6 key usage codes). The machine selects a row with
 row_sel (0..7) and reads 12 bits, 0 = pressed; row 7 is the two joysticks (joy_row, as MiSTer).

 The keys (row: bits 0..11), the PC key for the SK-1100 one:
   0: 1 Q A Z (Caps Lock = Eng Dier's) , K I 8
   1: 2 W S X Space . L O 9
   2: 3 E D C (Home / Backspace = CLR HOME) / ; P 0
   3: 4 R F V (Insert / Delete = INS DEL) (\ = PI) ' = : [ = @ - = -
   4: 5 T G B (bit 4 none) Down \ = ] ] = [ = = ^
   5: 6 Y H N (bit 4 none) Left Enter (bit 7 none) ` = Yen ... F1 / F3 = FUNC (bit 11)
   6: 7 U J M (bit 4 none) Right Up Esc / Pause = BREAK (bit 8), Alt = GRAPH (9), Ctrl (10), Shift (11)
 enable = 0: all rows read 1 (no keyboard).
*/

module sms_sk1100 (
	input  wire        clk,
	input  wire        enable,
	input  wire [55:0] kbd,       // kg_mcu2 KBD: [7:0] modifiers, then 6 usage codes
	input  wire [11:0] joy_row,   // row 7, 0 = pressed
	input  wire [2:0]  row_sel,
	output wire [11:0] row_data
);

// the matrix position of a key usage code: { valid, row (3), bit (4) }
function [7:0] pos;
	input [7:0] k;
	begin
		case (k)
		8'h1E: pos = { 1'b1, 3'd0, 4'd0 };   // 1
		8'h14: pos = { 1'b1, 3'd0, 4'd1 };   // Q
		8'h04: pos = { 1'b1, 3'd0, 4'd2 };   // A
		8'h1D: pos = { 1'b1, 3'd0, 4'd3 };   // Z
		8'h39: pos = { 1'b1, 3'd0, 4'd4 };   // Caps Lock: ENG DIER'S
		8'h36: pos = { 1'b1, 3'd0, 4'd5 };   // ,
		8'h0E: pos = { 1'b1, 3'd0, 4'd6 };   // K
		8'h0C: pos = { 1'b1, 3'd0, 4'd7 };   // I
		8'h25: pos = { 1'b1, 3'd0, 4'd8 };   // 8

		8'h1F: pos = { 1'b1, 3'd1, 4'd0 };   // 2
		8'h1A: pos = { 1'b1, 3'd1, 4'd1 };   // W
		8'h16: pos = { 1'b1, 3'd1, 4'd2 };   // S
		8'h1B: pos = { 1'b1, 3'd1, 4'd3 };   // X
		8'h2C: pos = { 1'b1, 3'd1, 4'd4 };   // Space
		8'h37: pos = { 1'b1, 3'd1, 4'd5 };   // .
		8'h0F: pos = { 1'b1, 3'd1, 4'd6 };   // L
		8'h12: pos = { 1'b1, 3'd1, 4'd7 };   // O
		8'h26: pos = { 1'b1, 3'd1, 4'd8 };   // 9

		8'h20: pos = { 1'b1, 3'd2, 4'd0 };   // 3
		8'h08: pos = { 1'b1, 3'd2, 4'd1 };   // E
		8'h07: pos = { 1'b1, 3'd2, 4'd2 };   // D
		8'h06: pos = { 1'b1, 3'd2, 4'd3 };   // C
		8'h4A: pos = { 1'b1, 3'd2, 4'd4 };   // Home: CLR HOME
		8'h2A: pos = { 1'b1, 3'd2, 4'd4 };   // Backspace: CLR HOME
		8'h38: pos = { 1'b1, 3'd2, 4'd5 };   // /
		8'h33: pos = { 1'b1, 3'd2, 4'd6 };   // ;
		8'h13: pos = { 1'b1, 3'd2, 4'd7 };   // P
		8'h27: pos = { 1'b1, 3'd2, 4'd8 };   // 0

		8'h21: pos = { 1'b1, 3'd3, 4'd0 };   // 4
		8'h15: pos = { 1'b1, 3'd3, 4'd1 };   // R
		8'h09: pos = { 1'b1, 3'd3, 4'd2 };   // F
		8'h19: pos = { 1'b1, 3'd3, 4'd3 };   // V
		8'h49: pos = { 1'b1, 3'd3, 4'd4 };   // Insert: INS DEL
		8'h4C: pos = { 1'b1, 3'd3, 4'd4 };   // Delete: INS DEL
		8'h64: pos = { 1'b1, 3'd3, 4'd5 };   // the key next to left Shift: PI
		8'h87: pos = { 1'b1, 3'd3, 4'd5 };   // Int'l 1 (Ro): PI
		8'h34: pos = { 1'b1, 3'd3, 4'd6 };   // ': the : key
		8'h2F: pos = { 1'b1, 3'd3, 4'd7 };   // [: @
		8'h2D: pos = { 1'b1, 3'd3, 4'd8 };   // -

		8'h22: pos = { 1'b1, 3'd4, 4'd0 };   // 5
		8'h17: pos = { 1'b1, 3'd4, 4'd1 };   // T
		8'h0A: pos = { 1'b1, 3'd4, 4'd2 };   // G
		8'h05: pos = { 1'b1, 3'd4, 4'd3 };   // B
		8'h51: pos = { 1'b1, 3'd4, 4'd5 };   // Down
		8'h31: pos = { 1'b1, 3'd4, 4'd6 };   // \: ]
		8'h30: pos = { 1'b1, 3'd4, 4'd7 };   // ]: [
		8'h2E: pos = { 1'b1, 3'd4, 4'd8 };   // =: ^

		8'h23: pos = { 1'b1, 3'd5, 4'd0 };   // 6
		8'h1C: pos = { 1'b1, 3'd5, 4'd1 };   // Y
		8'h0B: pos = { 1'b1, 3'd5, 4'd2 };   // H
		8'h11: pos = { 1'b1, 3'd5, 4'd3 };   // N
		8'h50: pos = { 1'b1, 3'd5, 4'd5 };   // Left
		8'h28: pos = { 1'b1, 3'd5, 4'd6 };   // Enter: CR
		8'h58: pos = { 1'b1, 3'd5, 4'd6 };   // keypad Enter: CR
		8'h35: pos = { 1'b1, 3'd5, 4'd8 };   // `: Yen
		8'h3A: pos = { 1'b1, 3'd5, 4'd11 };  // F1: FUNC
		8'h3C: pos = { 1'b1, 3'd5, 4'd11 };  // F3: FUNC

		8'h24: pos = { 1'b1, 3'd6, 4'd0 };   // 7
		8'h18: pos = { 1'b1, 3'd6, 4'd1 };   // U
		8'h0D: pos = { 1'b1, 3'd6, 4'd2 };   // J
		8'h10: pos = { 1'b1, 3'd6, 4'd3 };   // M
		8'h4F: pos = { 1'b1, 3'd6, 4'd5 };   // Right
		8'h52: pos = { 1'b1, 3'd6, 4'd6 };   // Up
		8'h29: pos = { 1'b1, 3'd6, 4'd8 };   // Esc: BREAK
		8'h48: pos = { 1'b1, 3'd6, 4'd8 };   // Pause: BREAK
		default: pos = 8'h00;
		endcase
	end
endfunction

// the pressed keys of the report as 7 rows of 12 bits (1 = pressed)
function [83:0] mark;
	input [7:0] p;
	begin
		mark = 84'd0;
		if (p[7]) mark[p[6:4] * 12 + p[3:0]] = 1'b1;
	end
endfunction

reg [83:0] keys = 84'd0;
always @(posedge clk) begin
	keys <= mark(pos(kbd[15:8])) | mark(pos(kbd[23:16])) | mark(pos(kbd[31:24])) |
	        mark(pos(kbd[39:32])) | mark(pos(kbd[47:40])) | mark(pos(kbd[55:48]));
	// the modifiers: Alt = GRAPH, Ctrl, Shift
	keys[6 * 12 + 9]  <= kbd[2] | kbd[6];
	keys[6 * 12 + 10] <= kbd[0] | kbd[4];
	keys[6 * 12 + 11] <= kbd[1] | kbd[5];
end

wire [11:0] row = row_sel == 3'd7 ? joy_row : ~keys[row_sel * 12 +: 12];
assign row_data = enable ? row : 12'hFFF;

endmodule
