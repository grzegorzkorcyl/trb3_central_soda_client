library ieee;
use ieee.std_logic_1164.all;
--use ieee.numeric_std.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb_net16_hub_func.all; 
use work.soda_components.all;

entity soda_calibration_timer is
	generic(
		cCALIBRATION_TIMEOUT		: natural range 1 to 5000	:= cSODA_CALIBRATION_TIMEOUT	-- clock-period in ns
		);
	port(
		SODACLK						: in	std_logic; -- fabric clock
		RESET							: in	std_logic; -- synchronous reset
		CLEAR							: in	std_logic; -- asynchronous reset
		CLK_EN						: in	std_logic; 
		--Internal Connection
		START_CALIBRATION			: in	std_logic := '0';
		END_CALIBRATION			: in	std_logic := '0';
		CALIBRATION_RUNNING		: out	std_logic := '0';	-- 
		VALID_OUT					: out	std_logic := '0';	-- 
		CALIB_TIME_OUT				: out	std_logic_vector(15 downto 0) := (others => '0');
		TIMEOUT_ERROR				: out std_logic := '0'
	);
end soda_calibration_timer;

architecture Behavioral of soda_calibration_timer is

	constant	cCALIBRATION_LIMIT		: std_logic_vector(11 downto 0)	:= conv_std_logic_vector((cSODA_CALIBRATION_TIMEOUT / cSODA_CLOCK_PERIOD), 12);

	signal	calibration_running_S	: std_logic	:= '0';
	signal	calibration_timer_S		: std_logic_vector(15 downto 0)	:= (others => '0');		-- from super-burst-nr-generator

begin

	CALIBRATION_RUNNING	<=  calibration_running_S;

	calibration_fsm_proc : process(SODACLK)
	begin
		if rising_edge(SODACLK) then
			if (RESET='1') then
				VALID_OUT							<= '0';
				CALIB_TIME_OUT						<= (others => '0');
				calibration_running_S			<= '0';
				calibration_timer_S				<=	(others => '0');
				TIMEOUT_ERROR						<= '0';
			else
				if (START_CALIBRATION='1') then
					calibration_running_S		<= '1';
					calibration_timer_S			<= (others => '0');
					VALID_OUT						<= '0';
					CALIB_TIME_OUT					<= (others => '0');
					TIMEOUT_ERROR					<= '0';						-- reset timeout error at start of new calibration
				elsif (END_CALIBRATION='1') then
					calibration_running_S		<= '0';
					VALID_OUT						<= '1';
					CALIB_TIME_OUT					<= calibration_timer_S;
					TIMEOUT_ERROR					<= '0';						-- reset timeout error because a correct reply was received
				elsif (calibration_timer_S = cCALIBRATION_TIMEOUT) then
					calibration_running_S		<= '0';
					VALID_OUT						<= '1';
					CALIB_TIME_OUT					<= calibration_timer_S;
					TIMEOUT_ERROR					<= '1';						-- set timeout error because NO correct reply was received
				elsif (calibration_running_S='1') then
					calibration_timer_S			<= calibration_timer_S + 1;
				end if;
			end if;
		end if;
	end process;

end architecture;