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

entity soda_start_of_burst_control is
	generic(
		CLOCK_PERIOD			: natural range 1 to 50	:= cSODA_CLOCK_PERIOD;	-- clock-period in ns
		CYCLE_PERIOD			: natural range 5 to 50	:= cSODA_CYCLE_PERIOD;	-- cycle-period in ns
		BURST_PERIOD			: natural 					:= cBURST_PERIOD			-- burst-period in ns
		);
	port(
		SODA_CLK					: in	std_logic; -- fabric clock
		RESET						: in	std_logic; -- synchronous reset
		SODA_BURST_PULSE_OUT	: out	std_logic := '0';
		SODA_40MHZ_CYCLE_OUT	: out	std_logic := '0'
		);
end soda_start_of_burst_control;

architecture Behavioral of soda_start_of_burst_control is

	constant	cCLOCKS_PER_CYCLE			: std_logic_vector(15 downto 0)	:= conv_std_logic_vector((CYCLE_PERIOD / CLOCK_PERIOD) - 1, 16);
	constant	cCYCLES_PER_BURST			: std_logic_vector(15 downto 0)	:= conv_std_logic_vector((BURST_PERIOD / CYCLE_PERIOD) - 1, 16);

	signal	cycle_counter_S			: std_logic_vector(15 downto 0)	:= (others => '0');
	signal	burst_counter_S			: std_logic_vector(15 downto 0)	:= (others => '0');
	

begin

	cycle_n_burst_pulse_proc : process(SODA_CLK)
	begin
		if rising_edge(SODA_CLK) then
			if (RESET='1') then
				cycle_counter_S			<= cCLOCKS_PER_CYCLE;
				burst_counter_S			<= cCYCLES_PER_BURST;
				SODA_40MHZ_CYCLE_OUT		<= '0';
				SODA_BURST_PULSE_OUT		<= '0';
			elsif (cycle_counter_S=0) then
				cycle_counter_S			<= cCLOCKS_PER_CYCLE;
				SODA_40MHZ_CYCLE_OUT		<= '1';
				if (burst_counter_S=0) then
					burst_counter_S		<= cCYCLES_PER_BURST;
					SODA_BURST_PULSE_OUT	<= '1';
				else
					burst_counter_S		<= burst_counter_S - 1;
					SODA_BURST_PULSE_OUT	<= '0';
				end if;
			else
				cycle_counter_S			<= cycle_counter_S - 1;
				SODA_40MHZ_CYCLE_OUT		<= '0';
			end if;
		end if;
	end process;
	

end Behavioral;
