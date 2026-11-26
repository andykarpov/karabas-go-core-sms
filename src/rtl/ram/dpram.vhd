-- karabas: inferred replacement of the altsyncram dpram of SMS_MiSTer (rtl/dpram.vhd), same entity.
-- True dual port, one read cycle per port; read during write on the other port = old data
-- (mixed_port_rdwr "OLD_DATA" of the VDP VRAM), own-port read during write = old data too.
-- init_file and outdata_reg_* are accepted and ignored (nothing in the core uses them).
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dpram is
	generic (
		init_file       : string := " ";
		widthad_a       : natural;
		width_a         : natural := 8;
		mixed_port_rdwr : string := "DONT_CARE";
		outdata_reg_a   : string := "UNREGISTERED";
		outdata_reg_b   : string := "UNREGISTERED"
	);
	port (
		address_a : in  std_logic_vector(widthad_a-1 downto 0);
		address_b : in  std_logic_vector(widthad_a-1 downto 0);
		clock_a   : in  std_logic;
		clock_b   : in  std_logic;
		data_a    : in  std_logic_vector(width_a-1 downto 0);
		data_b    : in  std_logic_vector(width_a-1 downto 0);
		wren_a    : in  std_logic := '1';
		wren_b    : in  std_logic := '1';
		q_a       : out std_logic_vector(width_a-1 downto 0);
		q_b       : out std_logic_vector(width_a-1 downto 0)
	);
end dpram;

architecture rtl of dpram is
	type t_ram is array (0 to 2**widthad_a-1) of std_logic_vector(width_a-1 downto 0);
	shared variable ram : t_ram;
begin
	process (clock_a)
	begin
		if rising_edge(clock_a) then
			q_a <= ram(to_integer(unsigned(address_a)));
			if wren_a = '1' then
				ram(to_integer(unsigned(address_a))) := data_a;
			end if;
		end if;
	end process;

	process (clock_b)
	begin
		if rising_edge(clock_b) then
			q_b <= ram(to_integer(unsigned(address_b)));
			if wren_b = '1' then
				ram(to_integer(unsigned(address_b))) := data_b;
			end if;
		end if;
	end process;
end rtl;
