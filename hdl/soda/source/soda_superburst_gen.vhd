library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.STD_LOGIC_ARITH.ALL;
use ieee.std_logic_unsigned.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb_net16_hub_func.all; 
use work.soda_components.all;

entity soda_superburst_generator is
	generic(
		BURST_COUNT : natural range 4 to 256 := 16   -- number of bursts to be counted between super-bursts
		);
	port(
		SODACLK						: in	std_logic; -- fabric clock
		RESET							: in	std_logic; -- synchronous reset
		ENABLE						: in	std_logic := '1';
		SODA_BURST_PULSE_IN		: in	std_logic := '0';	-- 
		START_OF_SUPERBURST_OUT	: out	std_logic := '0';
		SUPER_BURST_NR_OUT		: out	std_logic_vector(30 downto 0) := (others => '0');
		SODA_CMD_WINDOW_OUT		: out	std_logic := '0'
		);
end soda_superburst_generator;

architecture Behavioral of soda_superburst_generator is

	constant	cBURST_COUNT				: std_logic_vector(7 downto 0)	:= conv_std_logic_vector(BURST_COUNT - 1,8);

	signal	soda_burst_pulse_S		: std_logic	:= '0';
	signal	super_burst_nr_S			: std_logic_vector(30 downto 0)	:= (others => '0');		-- from super-burst-nr-generator
	signal	burst_counter_S			: std_logic_vector(7 downto 0)	:= (others => '0');		-- from super-burst-nr-generator
	

begin

	SUPER_BURST_NR_OUT		<=	super_burst_nr_S;
	
	burst_pulse_edge_proc : process(SODACLK)
	begin
		if rising_edge(SODACLK) then
			soda_burst_pulse_S <= SODA_BURST_PULSE_IN;
			if (RESET='1') then
				burst_counter_S	<= cBURST_COUNT;
				START_OF_SUPERBURST_OUT	<= '0';
				super_burst_nr_S			<= (others => '0');
			elsif ((SODA_BURST_PULSE_IN = '1') and (soda_burst_pulse_S = '0') and (ENABLE='1')) then
				if (burst_counter_S = x"00") then
					START_OF_SUPERBURST_OUT	<= '1';
					super_burst_nr_S			<= super_burst_nr_S + 1;
					burst_counter_S	<= cBURST_COUNT;
				else
					START_OF_SUPERBURST_OUT	<= '0';
					burst_counter_s	<=	burst_counter_s - 1;
				end if;
			else
				START_OF_SUPERBURST_OUT		<= '0';
			end if;
		end if;
	end process;

	soda_cmd_window_proc : process(SODACLK)
	begin
		if rising_edge(SODACLK) then
			if (RESET='1') then
				SODA_CMD_WINDOW_OUT		<= '0';
			elsif (burst_counter_S = (cBURST_COUNT - 1)) then
				SODA_CMD_WINDOW_OUT		<= '1';
			elsif (burst_counter_S = 2) then
				SODA_CMD_WINDOW_OUT		<= '0';
			end if;
		end if;
	end process;

end Behavioral;