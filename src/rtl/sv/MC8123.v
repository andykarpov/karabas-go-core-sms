module MC8123_rom_decrypt (
	clk,
	m1,
	a,
	d,
	prog_d,
	key_a,
	key_d
);
	reg _sv2v_0;
	input clk;
	input m1;
	input [15:0] a;
	output reg [7:0] d;
	input [7:0] prog_d;
	output wire [12:0] key_a;
	input [7:0] key_d;
	assign key_a = {~m1, a[15:10], a[8], a[6], a[4], a[2:0]};
	wire [7:0] key = ~key_d;
	wire [2:0] decrypt_type = {key[4] ^ key[5], ((key[0] ^ key[1]) ^ key[2]) ^ key[4], (key[0] ^ key[2]) ~^ m1};
	wire [1:0] swap = {key[2] ^ key[3], key[0] ^ key[1]};
	wire [3:0] param = {(key[1] ^ key[6]) ^ key[7], (key[0] ^ key[1]) ^ key[6], (key[0] ^ key[2]) ^ key[3], key[0] ~^ m1};
	reg s;
	reg t;
	reg [7:0] v;
	function [7:0] decrypt_type_0;
		input [7:0] value;
		input [3:0] p;
		input [1:0] swap;
		begin
			v = value;
			case (swap)
				0: v = {v[7], v[5], v[3], v[1], v[2], v[0], v[6], v[4]};
				1: v = {v[5], v[3], v[7], v[2], v[1], v[0], v[4], v[6]};
				2: v = {v[0], v[3], v[4], v[6], v[7], v[1], v[5], v[2]};
				3: v = {v[0], v[7], v[3], v[2], v[6], v[4], v[1], v[5]};
			endcase
			s = p[3] & v[7];
			t = p[2] & v[6];
			v = {((v[7] ^ t) ^ v[6]) ^ p[1], (v[6] ^ (p[1] & ((v[7] ^ t) ^ v[6]))) ^ p[1], ((((v[5] ^ s) ^ v[2]) ^ t) ^ p[2]) ^ p[0], ~v[4], ~v[3] ^ s, (v[2] ^ t) ^ p[2], ~v[1] ^ t, ((((v[0] ^ s) ^ v[2]) ^ t) ^ p[2]) ^ p[0]};
			decrypt_type_0 = (p[0] ? {v[7], v[6], v[5], v[1], v[4], v[3], v[2], v[0]} : v);
		end
	endfunction
	function [7:0] decrypt_type_1a;
		input [7:0] value;
		input [3:0] p;
		input [1:0] swap;
		begin
			v = value;
			case (swap)
				0: v = {v[4], v[2], v[6], v[5], v[3], v[7], v[1], v[0]};
				1: v = {v[6], v[0], v[5], v[4], v[3], v[2], v[1], v[7]};
				2: v = {v[2], v[3], v[6], v[1], v[4], v[0], v[7], v[5]};
				3: v = {v[6], v[5], v[1], v[3], v[2], v[7], v[0], v[4]};
			endcase
			v = (p[2] ? {v[7], v[6], v[1], v[5], v[3], v[2], v[4], v[0]} : v);
			v = {(v[7] ^ v[4]) ^ p[3], (((~v[6] ^ v[7]) ^ v[2]) ^ v[4]) ^ p[1], v[5], (v[4] ^ v[7]) ^ v[2], (((~v[3] ^ v[7]) ^ v[6]) ^ v[2]) ^ p[1], (v[2] ^ v[4]) ^ p[3], ~v[1] ^ v[2], ~v[0] ^ v[1]};
			decrypt_type_1a = (p[0] ? {v[7], v[6], v[1], v[4], v[3], v[2], v[5], v[0]} : v);
		end
	endfunction
	function [7:0] decrypt_type_1b;
		input [7:0] value;
		input [3:0] p;
		input [1:0] swap;
		begin
			v = value;
			case (swap)
				0: v = {v[1], v[0], v[3], v[2], v[5], v[6], v[4], v[7]};
				1: v = {v[2], v[0], v[5], v[1], v[7], v[4], v[6], v[3]};
				2: v = {v[6], v[4], v[7], v[2], v[0], v[5], v[1], v[3]};
				3: v = {v[7], v[1], v[3], v[6], v[0], v[2], v[5], v[4]};
			endcase
			s = v[2] & v[0];
			v = {(((v[7] ^ s) ^ v[5]) ^ v[3]) ^ p[2], (((((~v[6] ^ v[4]) ^ s) ^ v[0]) ^ v[3]) ^ p[2]) ^ p[0], ((v[5] ^ v[4]) ^ s) ^ v[1], ((~v[4] ^ s) ^ p[3]) ^ p[1], (v[3] ^ p[1]) ^ p[2], (((((v[2] ^ v[7]) ^ s) ^ v[5]) ^ v[0]) ^ v[3]) ^ p[0], ((((v[1] ^ v[6]) ^ v[0]) ^ v[3]) ^ p[3]) ^ p[0], ((~v[0] ^ v[3]) ^ p[0]) ^ p[2]};
			decrypt_type_1b = v;
		end
	endfunction
	function [7:0] decrypt_type_2a;
		input [7:0] value;
		input [3:0] p;
		input [1:0] swap;
		begin
			v = value;
			case (swap)
				0: v = {v[0], v[1], v[4], v[3], v[5], v[6], v[2], v[7]};
				1: v = {v[6], v[3], v[0], v[5], v[7], v[4], v[1], v[2]};
				2: v = {v[1], v[6], v[4], v[5], v[0], v[3], v[7], v[2]};
				3: v = {v[4], v[6], v[7], v[5], v[2], v[3], v[1], v[0]};
			endcase
			v = (v[3] || (p[1] & v[2]) ? {v[6], v[0], v[7], v[4], v[3], v[2], v[1], v[5]} : v);
			v = {~v[7] ^ v[5], ~v[6] ^ v[0], ~v[5] ^ v[6], ~v[4] ^ p[2], (v[3] ^ v[4]) ^ p[2], (v[2] ^ v[1]) ^ p[2], ~v[1] ^ p[2], (v[0] ^ v[4]) ^ p[2]};
			case ({p[3], p[0]})
				1: v = {v[7], v[6], v[5], v[2], v[1], v[3], v[4], v[0]};
				2: v = {v[7], v[6], v[5], v[1], v[2], v[4], v[3], v[0]};
				3: v = {v[7], v[6], v[5], v[3], v[4], v[1], v[2], v[0]};
				default:
					;
			endcase
			decrypt_type_2a = v;
		end
	endfunction
	function [7:0] decrypt_type_2b;
		input [7:0] value;
		input [3:0] p;
		input [1:0] swap;
		begin
			v = value;
			case (swap)
				0: v = {v[1], v[3], v[4], v[6], v[5], v[7], v[0], v[2]};
				1: v = {v[0], v[1], v[5], v[4], v[7], v[3], v[2], v[6]};
				2: v = {v[3], v[5], v[4], v[1], v[6], v[2], v[0], v[7]};
				3: v = {v[5], v[2], v[3], v[0], v[4], v[7], v[6], v[1]};
			endcase
			s = v[7] & v[3];
			v = {((v[7] ^ v[5]) ^ s) ^ v[4], v[6] ^ s, ((v[5] ^ v[1]) ^ s) ^ v[4], v[4] ^ s, ((v[3] ^ v[5]) ^ s) ^ v[4], v[2] ^ v[7], (v[1] ^ s) ^ v[4], v[0] ^ s};
			s = v[5] & (v[7] ^ v[1]);
			v = {(((~v[7] ^ v[6]) ^ v[3]) ^ p[2]) ^ p[1], ((v[6] ^ v[3]) ^ p[3]) ^ p[2], (((v[5] ^ v[6]) ^ v[3]) ^ p[2]) ^ p[0], v[4] ^ s, ((~v[3] ^ v[2]) ^ p[3]) ^ p[2], (~v[2] ^ p[2]) ^ p[0], (((~v[1] ^ v[3]) ^ v[2]) ^ p[3]) ^ p[2], v[0] ^ s};
			decrypt_type_2b = v;
		end
	endfunction
	function [7:0] decrypt_type_3a;
		input [7:0] value;
		input [3:0] p;
		input [1:0] swap;
		begin
			v = value;
			case (swap)
				0: v = {v[5], v[3], v[1], v[7], v[0], v[2], v[6], v[4]};
				1: v = {v[3], v[1], v[2], v[5], v[4], v[7], v[0], v[6]};
				2: v = {v[5], v[6], v[1], v[2], v[7], v[0], v[4], v[3]};
				3: v = {v[5], v[6], v[7], v[0], v[4], v[2], v[1], v[3]};
			endcase
			v = {v[7] ^ v[2], v[6], v[5] ^ v[2], v[4] ^ v[2], v[3], v[2], v[1], v[0] ^ v[3]};
			v = (p[0] ? {v[7], v[2], v[5], v[4], v[3], v[1], v[0], v[6]} : v);
			v = {v[7], v[6] ^ v[1], v[5], (v[4] ^ v[3]) ^ p[3], v[3] ^ p[3], v[2] ^ v[3], v[1] ^ v[3], v[0] ^ v[1]};
			v = (v[3] ? {v[5], v[6], v[7], v[4], v[3], v[2], v[1], v[0]} : v);
			v = {v[7] ^ p[2], ~v[6], ~v[5], ~v[4] ^ p[1], ~v[3], v[2] ^ v[5], v[1] ^ v[5], v[0] ^ p[0]};
			decrypt_type_3a = v;
		end
	endfunction
	function [7:0] decrypt_type_3b;
		input [7:0] value;
		input [3:0] p;
		input [1:0] swap;
		begin
			v = value;
			case (swap)
				0: v = {v[3], v[7], v[5], v[4], v[0], v[6], v[2], v[1]};
				1: v = {v[7], v[5], v[4], v[6], v[1], v[2], v[0], v[3]};
				2: v = {v[7], v[4], v[3], v[0], v[5], v[1], v[6], v[2]};
				3: v = {v[2], v[6], v[4], v[1], v[3], v[7], v[0], v[5]};
			endcase
			v = (v[2] ^ v[7] ? {v[7], v[6], v[3], v[4], v[5], v[2], v[1], v[0]} : v);
			s = v[2] ^ p[3];
			t = v[4] ^ v[1];
			v = {(v[7] ^ s) ^ p[3], v[6] ^ t, v[5], v[4] ^ v[1], v[3], v[2] ^ v[1], v[1] ^ ((((v[7] ^ s) & (v[6] ^ t)) ^ v[7]) ^ s), v[0] ^ p[2]};
			v = (p[3] ? {v[4], v[6], v[3], v[2], v[5], v[0], v[1], v[7]} : v);
			v = {v[7] ^ p[1], v[6], ~v[5], v[4] ^ v[5], ~v[3] ^ p[0], ~v[2] ^ v[7], v[1] ^ v[4], v[0]};
			decrypt_type_3b = v;
		end
	endfunction
	always @(posedge clk)
		case (decrypt_type)
			0: d <= decrypt_type_0(prog_d, param, swap);
			1: d <= decrypt_type_0(prog_d, param, swap);
			2: d <= decrypt_type_1a(prog_d, param, swap);
			3: d <= decrypt_type_1b(prog_d, param, swap);
			4: d <= decrypt_type_2a(prog_d, param, swap);
			5: d <= decrypt_type_2b(prog_d, param, swap);
			6: d <= decrypt_type_3a(prog_d, param, swap);
			7: d <= decrypt_type_3b(prog_d, param, swap);
		endcase
	initial _sv2v_0 = 0;
endmodule
