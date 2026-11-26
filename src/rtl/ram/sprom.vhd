-- karabas: inferred replacement of the altsyncram sprom of SMS_MiSTer (rtl/sprom.vhd), same entity.
-- init_file: a name ending in ".bin" = a text file of one word per line as binary digits (made
-- from a .mif by src/tools/mif2bin.py); any other name (the .mif of upstream) = zeros.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity sprom is
	generic (
		init_file     : string := "";
		widthad_a     : natural;
		width_a       : natural := 8;
		outdata_reg_a : string := "UNREGISTERED"
	);
	port (
		address : in  std_logic_vector(widthad_a-1 downto 0);
		clock   : in  std_logic;
		q       : out std_logic_vector(width_a-1 downto 0)
	);
end sprom;

architecture rtl of sprom is
	type t_rom is array (0 to 2**widthad_a-1) of std_logic_vector(width_a-1 downto 0);

	impure function load(name : string) return t_rom is
		file f      : text;
		variable l  : line;
		variable bv : bit_vector(width_a-1 downto 0);
		variable r  : t_rom := (others => (others => '0'));
	begin
		if name'length < 4 or name(name'right-3 to name'right) /= ".bin" then
			return r;
		end if;
		file_open(f, name, read_mode);
		for i in t_rom'range loop
			exit when endfile(f);
			readline(f, l);
			read(l, bv);
			r(i) := to_stdlogicvector(bv);
		end loop;
		file_close(f);
		return r;
	end function;

	signal rom : t_rom := load(init_file);
begin
	process (clock)
	begin
		if rising_edge(clock) then
			q <= rom(to_integer(unsigned(address)));
		end if;
	end process;
end rtl;
