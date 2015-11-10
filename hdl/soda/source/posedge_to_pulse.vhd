-----------------------------------------------------------------------------------
-- posedge_to_pulse
--		Makes pulse with duration 1 clock-cycle from positive edge
--	
-- inputs
--		clock_in : clock input for input signal
--		clock_out : clock input to synchronize to
--		en_clk : clock enable
--		signal_in : rising edge of this signal will result in pulse
--
--	output
--		pulse : pulse output : one clock cycle '1'
--
-----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;

entity posedge_to_pulse is
		port (
			IN_CLK			: in  std_logic;
			OUT_CLK			: in  std_logic;
			CLK_EN			: in  std_logic;
			SIGNAL_IN		: in  std_logic;
			PULSE_OUT		: out std_logic
		);
end posedge_to_pulse;

architecture behavioral of posedge_to_pulse is

	signal resetff				: std_logic := '0';
	signal last_signal_in	: std_logic := '0';
	signal qff					: std_logic := '0'; 
	signal qff1					: std_logic := '0'; 
	signal qff2					: std_logic := '0'; 
	signal qff3					: std_logic := '0'; 
	begin  

	process (IN_CLK)
	begin
		if rising_edge(IN_CLK) then
			if resetff='1' then
				qff <= '0';
			elsif (CLK_EN='1') and ((SIGNAL_IN='1') and (qff='0') and (last_signal_in='0')) then 
				qff <= '1';
			else
				qff <= qff;
			end if;
			last_signal_in <= SIGNAL_IN;
		end if;
	end process;

	resetff <= qff2;

	process (OUT_CLK)
	begin
		if rising_edge(OUT_CLK) then
			if qff3='0' and qff2='1' then 
				PULSE_OUT	<= '1'; 
			else 
				PULSE_OUT	<= '0';
			end if;
			qff3 <= qff2;
			qff2 <= qff1;
			qff1 <= qff;
		end if;
	end process; 


end behavioral;

