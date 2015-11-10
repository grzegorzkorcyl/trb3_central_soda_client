library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb_net16_hub_func.all; 
use work.soda_components.all;

entity soda_reply_handler is
	port(
		SODACLK						: in	std_logic; -- fabric clock
		RESET							: in	std_logic; -- synchronous reset
		CLEAR							: in	std_logic; -- asynchronous reset
		CLK_EN						: in	std_logic;
		--Internal Connection
		EXPECTED_REPLY_IN			: in	std_logic_vector(7 downto 0) := (others => '0');
		RX_DLM_IN					: in	std_logic	:= '0';
		RX_DLM_WORD_IN				: in	std_logic_vector(7 downto 0)	:= (others => '0');
		REPLY_VALID_OUT			: out std_logic := '0';
		REPLY_OK_OUT				: out std_logic := '0'
	);
end soda_reply_handler;

architecture Behavioral of soda_reply_handler is

	-- type		packet_state_type is (	c_RST, c_IDLE, c_ERROR,	c_REPLY, c_DONE);
	-- signal	reply_recv_state_S				:	packet_state_type := c_IDLE;

begin

	reply_fsm_proc : process(SODACLK)
	begin
		if rising_edge(SODACLK) then
			REPLY_VALID_OUT <= '0';
			REPLY_OK_OUT <= '0';
			if (RX_DLM_IN='1') then
				REPLY_VALID_OUT <= '1';
				if (EXPECTED_REPLY_IN = RX_DLM_WORD_IN) then
					REPLY_OK_OUT <= '1';
				end if;
			end if;
		end if;
	end process;
	
	-- reply_fsm_proc : process(SODACLK)
	-- begin
		-- if rising_edge(SODACLK) then
			-- if (RESET='1') then
				-- REPLY_VALID_OUT					<= '0';
				-- REPLY_OK_OUT						<= '0';
				-- reply_recv_state_S				<= c_IDLE;
			-- else
				-- REPLY_VALID_OUT					<= '0';
				-- case reply_recv_state_S is
					-- when c_IDLE	=>
						-- if (RX_DLM_IN='1') then
							-- reply_recv_state_S	<= c_REPLY;
							-- REPLY_VALID_OUT		<= '1';
							-- if (EXPECTED_REPLY_IN = RX_DLM_WORD_IN) then
								-- REPLY_OK_OUT		<= '1';
							-- else
								-- REPLY_OK_OUT		<= '0';
							-- end if;
						-- end if;
					-- when c_REPLY =>
						-- REPLY_VALID_OUT			<= '0';
						-- REPLY_OK_OUT				<= '0';
						-- if (RX_DLM_IN='0') then
							-- reply_recv_state_S	<= c_IDLE;
						-- else
							-- reply_recv_state_S	<= c_ERROR;
						-- end if;
					-- when c_ERROR	=>
						-- reply_recv_state_S		<= c_IDLE;
						-- REPLY_OK_OUT				<= '0';
						-- REPLY_OK_OUT				<= '0';
					-- when others =>
						-- reply_recv_state_S		<= c_IDLE;
						-- REPLY_OK_OUT				<= '0';
				-- end case;
			-- end if;
		-- end if;
	-- end process;

end architecture;