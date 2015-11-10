library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb_net16_hub_func.all; 
use work.soda_components.all;

entity soda_packet_handler is
	generic(
		CLOCKSper25ns					: integer := 5 -- PS
	);
	port(
		SODACLK							: in	std_logic; -- fabric clock
		RESET								: in	std_logic; -- synchronous reset
		CLEAR								: in	std_logic; -- asynchronous reset
		CLK_EN							: in	std_logic;
		--Internal Connection
		START_OF_SUPERBURST_OUT		: out std_logic	:= '0';
		SUPER_BURST_NR_OUT			: out std_logic_vector(30 downto 0) := (others => '0');
		START_OF_CALIBRATION_OUT	: out std_logic	:= '0';
		SODA_CMD_VALID_OUT			: out std_logic := '0';
		SODA_CMD_WORD_OUT				: out std_logic_vector(30 downto 0) := (others => '0');
		SODA_CYCLE_OUT				: out std_logic := '0'; -- PS
		RX_DLM_IN						: in std_logic;
		RX_DLM_WORD_IN					: in	std_logic_vector(7 downto 0) := (others => '0')
	);
end soda_packet_handler;

architecture Behavioral of soda_packet_handler is

	signal	soda_pkt_word_S	: std_logic_vector(31 downto 0) := (others => '0');
	signal	soda_pkt_valid_S	: std_logic := '0';
	
	type		packet_state_type is (	c_RST, c_IDLE, c_ERROR,
												c_SODA_PKT1, c_SODA_PKT2, c_SODA_PKT3, c_SODA_PKT4,
												c_SODA_PKT5, c_SODA_PKT6, c_SODA_PKT7, c_SODA_PKT8
											);
	signal	packet_state_S				:	packet_state_type := c_IDLE;
	signal	SODA40MHz_counter_S			: integer range 0 to CLOCKSper25ns-1 := 0; -- PS

begin

	packet_fsm_proc : process(SODACLK)
	begin
		if rising_edge(SODACLK) then
			if (RESET='1') then
				packet_state_S	<=	c_RST;
			else
				case packet_state_S is
					when c_RST	=>
						if (RX_DLM_IN='1') then						-- received K28.7 #1
							packet_state_S	<= c_SODA_PKT1;
						else
							packet_state_S	<= c_IDLE;
						end if;
					when c_IDLE	=>
						if (RX_DLM_IN='1') then						-- received K28.7 #1
							packet_state_S	<= c_SODA_PKT1;
						else
							packet_state_S	<= c_IDLE;
						end if;
					when c_SODA_PKT1	=>
						if (RX_DLM_IN='0') then						-- possibly received data-byte
							packet_state_S	<= c_SODA_PKT2;
						else
							packet_state_S	<= c_ERROR;
						end if;
					when c_SODA_PKT2	=>
						if (RX_DLM_IN='1') then						-- received K28.7 #2
							packet_state_S	<= c_SODA_PKT3;
						else
							packet_state_S	<= c_ERROR;
						end if;
					when c_SODA_PKT3	=>
						if (RX_DLM_IN='0') then						-- possibly received data-byte
							packet_state_S	<= c_SODA_PKT4;
						else
							packet_state_S	<= c_ERROR;
						end if;
					when c_SODA_PKT4	=>
						if (RX_DLM_IN='1') then						-- received K28.7 #3
							packet_state_S	<= c_SODA_PKT5;
						else
							packet_state_S	<= c_ERROR;
						end if;
					when c_SODA_PKT5	=>
						if (RX_DLM_IN='0') then						-- possibly received data-byte
							packet_state_S	<= c_SODA_PKT6;
						else
							packet_state_S	<= c_ERROR;
						end if;
					when c_SODA_PKT6	=>
						if (RX_DLM_IN='1') then						-- received K28.7 #4
							packet_state_S	<= c_SODA_PKT7;
						else
							packet_state_S	<= c_ERROR;
						-- else do nothing
						end if;
					when c_SODA_PKT7	=>
						if (RX_DLM_IN='1') then
							packet_state_S	<= c_ERROR;	-- if there's an unexpected K28.7 there's too much data
						else
							packet_state_S	<= c_SODA_PKT8;
						end if;
					when c_SODA_PKT8	=>
						if (RX_DLM_IN='1') then						-- received K28.7 #4+1... must be another packet coming in....
							packet_state_S	<= c_SODA_PKT1;
						else
							packet_state_S	<= c_IDLE;
						end if;
					when c_ERROR	=>
							packet_state_S	<= c_IDLE;				-- TODO: Insert ERROR_HANDLER
					when others	=>
							packet_state_S	<= c_IDLE;
				end case;
			end if;
		end if;
	end process;

	soda_packet_interpreter_proc : process(SODACLK, packet_state_S)
	begin
		if rising_edge(SODACLK) then
			case packet_state_S is
					when c_RST	=>
						START_OF_SUPERBURST_OUT				<= '0';
						START_OF_CALIBRATION_OUT			<=	'0';
						SODA_CMD_VALID_OUT					<= '0';
						soda_pkt_valid_S						<= '0';
						soda_pkt_word_S						<= (others=>'0');
					when c_IDLE	=>
						START_OF_SUPERBURST_OUT				<= '0';
						START_OF_CALIBRATION_OUT			<=	'0';
						SODA_CMD_VALID_OUT					<= '0';
						soda_pkt_valid_S						<= '0';
						soda_pkt_word_S						<= (others=>'0');
					when c_SODA_PKT1 	=>
						START_OF_SUPERBURST_OUT				<= '0';
						START_OF_CALIBRATION_OUT			<=	'0';
						SODA_CMD_VALID_OUT					<= '0';
						soda_pkt_word_S(31 downto 24)		<=	RX_DLM_WORD_IN;
					when c_SODA_PKT2	=>
						-- do nothing -- disregard K28.7
					when c_SODA_PKT3	=>
						soda_pkt_word_S(23 downto 16)		<=	RX_DLM_WORD_IN;
					when c_SODA_PKT4	=>
						-- do nothing -- disregard K28.7
					when c_SODA_PKT5	=>
						soda_pkt_word_S(15 downto 8)		<=	RX_DLM_WORD_IN;
					when c_SODA_PKT6	=>
						-- do nothing -- disregard K28.7
					when c_SODA_PKT7	=>
						soda_pkt_word_S(7 downto 0)		<=	RX_DLM_WORD_IN;	-- get transmitted CRC
					when c_SODA_PKT8	=>
						soda_pkt_valid_S						<= '1';
						if (soda_pkt_word_S(31)= '1') then
							START_OF_SUPERBURST_OUT			<= '1';
							SUPER_BURST_NR_OUT				<= soda_pkt_word_S(30 downto 0);
						else
							SODA_CMD_VALID_OUT				<= '1';
							SODA_CMD_WORD_OUT					<= soda_pkt_word_S(30 downto 0);
							if soda_pkt_word_S(30)='1' then
								START_OF_CALIBRATION_OUT	<=	'1';
							end if;
						end if;
					when others	=>
 						START_OF_SUPERBURST_OUT				<= '0';
						START_OF_CALIBRATION_OUT			<=	'0';
						soda_pkt_valid_S						<= '0';
						soda_pkt_word_S						<= (others=>'0');
						SODA_CMD_VALID_OUT					<= '0';
						SODA_CMD_WORD_OUT						<= (others=>'0');
			end case;
			
		end if;
	end process;

-- PS : 40MHz clock cycle, synchronized to SODA
make_synchronous_40MHz_proc : process(SODACLK, packet_state_S)
	begin
		if rising_edge(SODACLK) then
			if ((packet_state_S=c_RST) or (packet_state_S=c_IDLE)) and (RX_DLM_IN='1') then
				SODA40MHz_counter_S <= 0;
			else
				if SODA40MHz_counter_S<CLOCKSper25ns-1 then
					SODA40MHz_counter_S <= SODA40MHz_counter_S+1;
				else
					SODA40MHz_counter_S <= 0;
				end if;
			end if;
			if SODA40MHz_counter_S=1 then 
				SODA_CYCLE_OUT <= '1';
			else
				SODA_CYCLE_OUT <= '0';
			end if;
		end if;
	end process;

end architecture;