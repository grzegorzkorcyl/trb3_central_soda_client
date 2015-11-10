library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb_net16_hub_func.all; 
use work.soda_components.all;

entity soda_client is
	port(
		SYSCLK					: in	std_logic; -- fabric clock
		SODACLK					: in	std_logic; -- recovered clock
		RESET						: in	std_logic; -- synchronous reset
		CLEAR						: in	std_logic; -- asynchronous reset
		CLK_EN					: in	std_logic; 

		RX_DLM_WORD_IN			: in	std_logic_vector(7 downto 0)	:= (others => '0');
		RX_DLM_IN				: in std_logic;
		TX_DLM_OUT				: out	std_logic;
		TX_DLM_WORD_OUT		: out	std_logic_vector(7 downto 0)	:= (others => '0');
		TX_DLM_PREVIEW_OUT	: out	std_logic	:= '0';	--PL!
		LINK_PHASE_IN			: in	std_logic	:= '0';	--PL!

		SODA_DATA_IN			: in	std_logic_vector(31 downto 0)	:= (others => '0');
		SODA_DATA_OUT			: out	std_logic_vector(31 downto 0)	:= (others => '0');
		SODA_ADDR_IN			: in	std_logic_vector(3 downto 0)	:= (others => '0');
		SODA_READ_IN			: in	std_logic := '0';
		SODA_WRITE_IN			: in	std_logic := '0';
		SODA_ACK_OUT			: out	std_logic := '0';
		LEDS_OUT       	   : out  std_logic_vector(3 downto 0);
		LINK_DEBUG_IN			: in	std_logic_vector(31 downto 0)	:= (others => '0')
	);
end soda_client;

architecture Behavioral of soda_client is

	--SODA
	signal soda_cmd_word_S				: std_logic_vector(30 downto 0)	:= (others => '0');
	signal soda_cmd_valid_S				: std_logic := '0';
	signal start_of_superburst_S		: std_logic := '0';
	signal super_burst_nr_S				: std_logic_vector(30 downto 0)	:= (others => '0');		-- from super-burst-nr-generator
	signal crc_data_S						: std_logic_vector(7 downto 0)	:= (others => '0');
	signal crc_valid_S					: std_logic := '0';
	
-- Signals
	type STATES is (SLEEP,RD_RDY,WR_RDY,RD_ACK,WR_ACK,DONE);
	signal CURRENT_STATE, NEXT_STATE: STATES;

-- slave bus signals
	signal bus_ack_x        : std_logic;
	signal bus_ack          : std_logic;
	signal store_wr_x       : std_logic;
	signal store_wr         : std_logic;
	signal store_rd_x       : std_logic;
	signal store_rd         : std_logic;
	signal buf_bus_data_out : std_logic_vector(31 downto 0);
	signal ledregister_i		: std_logic_vector(31 downto 0);
	signal tx_dlm_out_S		: std_logic;

--	debug
	signal debug_status_S		: std_logic_vector(31 downto 0)	:= (others => '0');
	signal debug_rx_cnt_S		: std_logic_vector(31 downto 0)	:= (others => '0');
	signal debug_tx_cnt_S		: std_logic_vector(31 downto 0)	:= (others => '0');
	signal debug_SOS_cnt_S		: std_logic_vector(31 downto 0)	:= (others => '0');
	signal debug_cmd_cnt_S		: std_logic_vector(31 downto 0)	:= (others => '0');

begin
	
	packet_handler : soda_packet_handler
		port map(
			SODACLK							=>	SODACLK,
			RESET								=> RESET,
			CLEAR								=>	'0',
			CLK_EN							=>	'1',
			--Internal Connection
			START_OF_SUPERBURST_OUT		=> start_of_superburst_S,
			SUPER_BURST_NR_OUT			=> super_burst_nr_S,
			SODA_CMD_VALID_OUT			=> soda_cmd_valid_S,
			SODA_CMD_WORD_OUT				=> soda_cmd_word_S,
--			CRC_VALID_OUT					=> crc_valid_S,
--			CRC_DATA_OUT					=> crc_data_S,
			RX_DLM_IN						=> RX_DLM_IN,
			RX_DLM_WORD_IN					=> RX_DLM_WORD_IN
		);

	reply_packet_builder : soda_reply_pkt_builder		
		port map(
			SODACLK					=>	SODACLK,
			RESET						=>	RESET,
			CLEAR						=>	'0',
			CLK_EN					=> CLK_EN,
			--Internal Connection
			LINK_PHASE_IN			=> LINK_PHASE_IN,
			START_OF_SUPERBURST	=> start_of_superburst_S,
			SUPER_BURST_NR_IN		=> super_burst_nr_S,
			SODA_CMD_STROBE_IN	=> soda_cmd_valid_S,
			SODA_CMD_WORD_IN		=> soda_cmd_word_S,
			TX_DLM_PREVIEW_OUT	=>	TX_DLM_PREVIEW_OUT,
			TX_DLM_OUT				=> tx_dlm_out_S,	--TX_DLM_OUT,
			TX_DLM_WORD_OUT		=> TX_DLM_WORD_OUT
		);

---------------------------------------------------------
-- RegIO Statemachine
---------------------------------------------------------
	STATE_MEM: process( SYSCLK)
	begin
		if( rising_edge(SYSCLK) ) then
			if( RESET = '1' ) then
				CURRENT_STATE <= SLEEP;
				bus_ack       <= '0';
				store_wr      <= '0';
				store_rd      <= '0';
			else
				CURRENT_STATE <= NEXT_STATE;
				bus_ack       <= bus_ack_x;
				store_wr      <= store_wr_x;
				store_rd      <= store_rd_x;
			end if;
		end if;
	end process STATE_MEM;

-- Transition matrix
	TRANSFORM: process(CURRENT_STATE, SODA_READ_IN, SODA_WRITE_IN )
	begin
		NEXT_STATE <= SLEEP;
		bus_ack_x  <= '0';
		store_wr_x <= '0';
		store_rd_x <= '0';
		case CURRENT_STATE is
			when SLEEP    =>
				if   ( (SODA_READ_IN = '1') ) then
					NEXT_STATE <= RD_RDY;
					store_rd_x <= '1';
				elsif( (SODA_WRITE_IN = '1') ) then
					NEXT_STATE <= WR_RDY;
					store_wr_x <= '1';
				else
					NEXT_STATE <= SLEEP;
				end if;
			when RD_RDY    =>
				NEXT_STATE <= RD_ACK;
			when WR_RDY    =>
				NEXT_STATE <= WR_ACK;
			when RD_ACK    =>
				if( SODA_READ_IN = '0' ) then
					NEXT_STATE <= DONE;
					bus_ack_x  <= '1';
				else
					NEXT_STATE <= RD_ACK;
					bus_ack_x  <= '1';
				end if;
			when WR_ACK    =>
				if( SODA_WRITE_IN = '0' ) then
					NEXT_STATE <= DONE;
					bus_ack_x  <= '1';
				else
					NEXT_STATE <= WR_ACK;
					bus_ack_x  <= '1';
				end if;
			when DONE    =>
				NEXT_STATE <= SLEEP;
			when others    =>
				NEXT_STATE <= SLEEP;
	end case;
end process TRANSFORM;


---------------------------------------------------------
-- data handling                                       --
---------------------------------------------------------
-- For sim purposes the CLIENT gets addresses 11XX
-- register write
	THE_WRITE_REG_PROC: process( SYSCLK )
	begin
		if( rising_edge(SYSCLK) ) then
			if   ( RESET = '1' ) then
				LEDregister_i		<= (others => '0');
			elsif( (store_wr = '1') and (SODA_ADDR_IN = B"0000") ) then
				LEDregister_i		<= SODA_DATA_IN;
			end if;
		end if;
	end process THE_WRITE_REG_PROC;
  
-- register read
	THE_READ_REG_PROC: process( SYSCLK )
	begin
		if( rising_edge(SYSCLK) ) then
			if   ( RESET = '1' ) then
				buf_bus_data_out	<= (others => '0');
			elsif( (store_rd = '1') and (SODA_ADDR_IN = "0000") ) then
				buf_bus_data_out	<= '0' & soda_cmd_word_S;
			elsif( (store_rd = '1') and (SODA_ADDR_IN = "0001") ) then
				buf_bus_data_out	<= '0' & super_burst_nr_S;
			elsif( (store_rd = '1') and (SODA_ADDR_IN = "0010") ) then
				buf_bus_data_out	<= LEDregister_i;
			elsif( (store_rd = '1') and (SODA_ADDR_IN = "0011") ) then
				buf_bus_data_out	<= debug_status_S;
			elsif( (store_rd = '1') and (SODA_ADDR_IN = "0100") ) then
				buf_bus_data_out	<= debug_rx_cnt_S;
			elsif( (store_rd = '1') and (SODA_ADDR_IN = "0101") ) then
				buf_bus_data_out	<= debug_tx_cnt_S;
			elsif( (store_rd = '1') and (SODA_ADDR_IN = "0110") ) then
				buf_bus_data_out	<= debug_sos_cnt_S;
			elsif( (store_rd = '1') and (SODA_ADDR_IN = "0111") ) then
				buf_bus_data_out	<= debug_cmd_cnt_S;
			end if;
		end if;
	end process THE_READ_REG_PROC;

--	debug signals
	DEBUG_CLIENT : process(SODACLK)
	begin
		if( rising_edge(SODACLK) ) then
			debug_status_S(0)		<= RESET;
			debug_status_S(1)		<= CLEAR;
			debug_status_S(2)		<= CLK_EN;
			if   ( RESET = '1' ) then
				debug_rx_cnt_S		<= (others => '0');
				debug_tx_cnt_S		<= (others => '0');
			else
				if (tx_dlm_out_S = '1') then
					debug_tx_cnt_S	<= debug_tx_cnt_S + 1;
				end if;
				if (RX_DLM_IN = '1') then
					debug_rx_cnt_S	<= debug_rx_cnt_S + 1;
				end if;
				if (start_of_superburst_S = '1') then
					debug_sos_cnt_S	<= debug_sos_cnt_S + 1;
				end if;
				if (soda_cmd_valid_S = '1') then
					debug_cmd_cnt_S	<= debug_cmd_cnt_S + 1;
				end if;
			end if;
		end if; 
	end process;

	debug_status_S(31 downto 3)		<=	LINK_DEBUG_IN(31 downto 3);
	TX_DLM_OUT								<= tx_dlm_out_S;
-- output signals
	LEDS_OUT									<= LEDregister_i(3 downto 0);
  
	SODA_DATA_OUT							<= buf_bus_data_out;
	SODA_ACK_OUT 							<= bus_ack;

end architecture;