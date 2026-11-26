-- karabas: inferred replacement of the altsyncram spram of SMS_MiSTer (rtl/spram.vhd), same entity.
-- One read cycle, read during write = new data (NEW_DATA_NO_NBE_READ). init_file is ignored.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spram is
	generic (
		init_file     : string := "none";
		widthad_a     : natural;
		width_a       : natural := 8;
		outdata_reg_a : string := "UNREGISTERED"
	);
	port (
		address : in  std_logic_vector(widthad_a-1 downto 0);
		clock   : in  std_logic;
		data    : in  std_logic_vector(width_a-1 downto 0);
		wren    : in  std_logic;
		q       : out std_logic_vector(width_a-1 downto 0)
	);
end spram;

architecture rtl of spram is
	type t_ram is array (0 to 2**widthad_a-1) of std_logic_vector(width_a-1 downto 0);
	signal ram : t_ram;
begin
	process (clock)
	begin
		if rising_edge(clock) then
			if wren = '1' then
				ram(to_integer(unsigned(address))) <= data;
				q <= data;
			else
				q <= ram(to_integer(unsigned(address)));
			end if;
		end if;
	end process;
end rtl;
