-- sms_machine: the SMS_MiSTer machine as the karabas core uses it: system + video timing + 8 KB work
-- RAM + the clock enables of the MiSTer top (clk_sys = 53.693175 MHz = 15 x 3.579545: CPU / 15,
-- VDP / 5, pixel / 10, sprites / 2), on the rising edge here (MiSTer: falling edge, same pattern).
-- Tied off: System E (second VDP / PSG, MC8123), Evolution, Game Genie, Gear-to-Gear link, the BIOS
-- (internal boot ROM and loaded BIOS), paddles, savestates; XST drops that logic.
-- Ports stay for what the board glue drives: cartridge ROM (SDRAM), cart RAM (nvram), pads, SK-1100
-- keyboard, video (x / y of the pixel on ce_pix, 12-bit colour), audio.
-- FM = false ties fm_ena to 0 so XST drops the VM2413; with FM = true fm_on switches it.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sms_machine is
	generic (
		FM : boolean := true
	);
	port (
		clk_sys   : in  std_logic;
		reset_n   : in  std_logic;
		gg        : in  std_logic;
		ggres     : in  std_logic;                    -- Game Gear: the 160 x 144 window only
		palettemode : in std_logic;                   -- SG-1000 / SC-3000: the TMS9918 palette
		pal       : in  std_logic;
		region    : in  std_logic;
		border    : in  std_logic;
		black_column : in std_logic;                  -- 1 = the masked left column (VDP reg 0 bit 5) black, not the backdrop
		sp64      : in  std_logic;                    -- 1 = more than 4 sprites per line in the TMS modes (SMS: MAX_SPPL 7 = 8 anyway)
		sc3000_en : in  std_logic;
		sk1100_en : in  std_logic;
		mapper_lock : in std_logic;
		cart_in   : in  std_logic;                    -- 1 = a cartridge is loaded (dbr of MiSTer)
		fm_on     : in  std_logic;                    -- the YM2413 (when FM = true)
		ce_cpu_o  : out std_logic;                    -- the CPU clock enable (clkref of the SDRAM)

		rom_rd    : out std_logic;
		rom_a     : out std_logic_vector(23 downto 0);
		rom_do    : in  std_logic_vector(7 downto 0);

		j1        : in  std_logic_vector(6 downto 0); -- th tr tl right left down up (active low)
		j2        : in  std_logic_vector(6 downto 0);
		pause     : in  std_logic;                    -- active low
		sk1100_row_sel  : out std_logic_vector(2 downto 0);
		sk1100_row_data : in  std_logic_vector(11 downto 0);

		ce_pix    : out std_logic;
		x         : out std_logic_vector(8 downto 0);
		y         : out std_logic_vector(8 downto 0);
		color     : out std_logic_vector(11 downto 0); -- b g r, 4 bits each
		smode_M1  : out std_logic;
		smode_M3  : out std_logic;
		hsync     : out std_logic;
		vsync     : out std_logic;
		hblank    : out std_logic;
		vblank    : out std_logic;
		audioL    : out std_logic_vector(15 downto 0);
		audioR    : out std_logic_vector(15 downto 0);

		nvram_a   : out std_logic_vector(14 downto 0);
		nvram_d   : out std_logic_vector(7 downto 0);
		nvram_we  : out std_logic;
		nvram_q   : in  std_logic_vector(7 downto 0)
	);
end sms_machine;

architecture rtl of sms_machine is
	signal clkd : unsigned(4 downto 0) := (others => '0');
	signal ce_cpu, ce_vdp, ce_pix_i, ce_sp : std_logic := '0';
	signal x_i, y_i : std_logic_vector(8 downto 0);
	signal vcounter_cpu : std_logic_vector(7 downto 0);
	signal mask_column, m1, m2, m3, m4 : std_logic;
	signal ram_a : std_logic_vector(13 downto 0);
	signal ram_d, ram_q : std_logic_vector(7 downto 0);
	signal ram_we : std_logic;
	signal fm_ena : std_logic;
begin
	fm_ena <= fm_on when FM else '0';
	ce_cpu_o <= ce_cpu;

	-- clock enables, as the always @(negedge clk_sys) block of SMS.sv
	process (clk_sys)
	begin
		if rising_edge(clk_sys) then
			ce_sp <= clkd(0);
			ce_vdp <= '0';
			ce_pix_i <= '0';
			ce_cpu <= '0';
			clkd <= clkd + 1;
			case to_integer(clkd) is
				when 29 => clkd <= (others => '0'); ce_vdp <= '1'; ce_pix_i <= '1';
				when 24 => ce_cpu <= '1'; ce_vdp <= '1';
				when 19 => ce_vdp <= '1'; ce_pix_i <= '1';
				when 14 => ce_vdp <= '1';
				when 9  => ce_cpu <= '1'; ce_vdp <= '1'; ce_pix_i <= '1';
				when 4  => ce_vdp <= '1';
				when others => null;
			end case;
		end if;
	end process;

	ce_pix <= ce_pix_i;
	x <= x_i;
	y <= y_i;
	smode_M1 <= m1;
	smode_M3 <= m3;

	vid : entity work.video
	port map (
		clk => clk_sys, ce_pix => ce_pix_i, pal => pal, border => border, ggres => ggres,
		mask_column => mask_column, cut_mask => '0',
		smode_M1 => m1, smode_M2 => m2, smode_M3 => m3, smode_M4 => m4,
		video_state_out => open,
		x => x_i, y => y_i, vcounter_cpu => vcounter_cpu,
		hsync => hsync, vsync => vsync, hblank => hblank, vblank => vblank
	);

	sys : entity work.system
	generic map (MAX_SPPL => 7, BASE_DIR => "")
	port map (
		clk_sys => clk_sys, ce_cpu => ce_cpu, ce_vdp => ce_vdp, ce_pix => ce_pix_i, ce_sp => ce_sp,
		turbo => '0', gg => gg, ggres => ggres, systeme => '0',
		bios_en => '0', ext_bios_sel => '0', ext_bios_loaded => '0',
		gg_bios_en => '0', ext_gg_bios_loaded => '0', GG_BIOSWEN => '0',
		GG_EN => '0', GG_CODE => (others => '0'), GG_RESET => '0', GG_AVAIL => open,
		gg_link_en => '0', gg_link_in => (others => '1'), gg_link_out => open,
		RESET_n => reset_n,
		rom_rd => rom_rd, rom_a => rom_a, rom_do => rom_do,
		j1_up => j1(0), j1_down => j1(1), j1_left => j1(2), j1_right => j1(3),
		j1_tl => j1(4), j1_tr => j1(5), j1_th => j1(6), j1_start => '1', j1_coin => '1', j1_a3 => '1',
		j2_up => j2(0), j2_down => j2(1), j2_left => j2(2), j2_right => j2(3),
		j2_tl => j2(4), j2_tr => j2(5), j2_th => j2(6), j2_start => '1', j2_coin => '1', j2_a3 => '1',
		pause => pause, soft_reset => '0',
		E0Type => "00", E1Use => '0', E2Use => '0', E0 => x"FF", F2 => x"FF", F3 => x"FF",
		has_paddle => '0', has_pedal => '0', paddle => x"00", paddle2 => x"00", pedal => x"00",
		sc3000_en => sc3000_en, sc_multicart_en => '0', sc_megacart_en => '0', sc_cart_ram => "00",
		sk1100_en => sk1100_en, sk1100_row_sel => sk1100_row_sel, sk1100_row_data => sk1100_row_data,
		j1_tr_out => open, j1_th_out => open, j2_tr_out => open, j2_th_out => open,
		x => x_i, y => y_i, vcounter_cpu => vcounter_cpu, color => color,
		palettemode => palettemode, mask_column => mask_column, black_column => black_column,
		smode_M1 => m1, smode_M2 => m2, smode_M3 => m3, smode_M4 => m4,
		ysj_quirk => '0', pal => pal, region => region,
		mapper_lock => mapper_lock, mapper_codies_force => '0', mapper_dahjee_a_force => '0',
		mapper_linear_force => '0', mapper_zemina_force => '0', mapper_evolution_force => '0',
		evolution_gg_active => open, evolution_active => open, mapper_eeprom_out => open,
		vdp_enables => "00", psg_enables => "00",
		audioL => audioL, audioR => audioR, fm_ena => fm_ena,
		dbr => cart_in, sp64 => sp64,
		ram_a => ram_a, ram_d => ram_d, ram_we => ram_we, ram_q => ram_q,
		nvram_a => nvram_a, nvram_d => nvram_d, nvram_we => nvram_we, nvram_q => nvram_q,
		encrypt => "00", key_a => open, key_d => x"00",
		ROMCL => clk_sys, ROMAD => (others => '0'), ROMDT => x"00", ROMEN => '0', BIOSWEN => '0',
		z80_reg_out => open, vdp_regs_out => open, vdp_cram_out => open, ss_vram_D => open,
		psg_out => open, psg_ext_out => open, psg2_ext_out => open, psg_div_out => open,
		audio_control_out => open, audio_quiescent => open, audio_phase_out => open,
		mapper_out => open, evolution_ss_out => open, eeprom_ss_out => open,
		z80_m1_n => open, z80_mreq_n => open, z80_iset => open,
		vdp2_regs_out => open, vdp2_cram_out => open, ss_vram2_D => open, psg2_out => open,
		io_state_out => open, fm_state_rdata => open, fm_initialized => open
	);

	wram : entity work.spram
	generic map (widthad_a => 13)
	port map (clock => clk_sys, address => ram_a(12 downto 0), data => ram_d, wren => ram_we, q => ram_q);
end rtl;
