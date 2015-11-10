library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb_net16_hub_func.all; 
use work.soda_components.all;

entity soda_source is
	port(
		SYSCLK					: in	std_logic; -- fabric clock
		SODACLK					: in	std_logic; -- clock for data to serdes
		RESET						: in	std_logic; -- synchronous reset

		SODA_BURST_PULSE_IN	: in	std_logic := '0';	-- 
		SODA_CYCLE_IN			: in	std_logic := '0';	-- 

		RX_DLM_WORD_IN			: in	std_logic_vector(7 downto 0) := (others => '0');
		RX_DLM_IN				: in	std_logic;
		TX_DLM_OUT				: out	std_logic;
		TX_DLM_WORD_OUT		: out	std_logic_vector(7 downto 0) := (others => '0');
		TX_DLM_PREVIEW_OUT	: out	std_logic	:= '0';	--PL!
		LINK_PHASE_IN			: in	std_logic	:= '0';	--PL!

		SODA_DATA_IN			: in	std_logic_vector(31 downto 0) := (others => '0');
		SODA_DATA_OUT			: out	std_logic_vector(31 downto 0) := (others => '0');
		SODA_ADDR_IN			: in	std_logic_vector(3 downto 0) := (others => '0');
		SODA_READ_IN			: in	std_logic := '0';
		SODA_WRITE_IN			: in	std_logic := '0';
		SODA_ACK_OUT			: out	std_logic := '0';
		LEDS_OUT       	   : out  std_logic_vector(3 downto 0)
	);
end soda_source;

architecture Behavioral of soda_source is

	--SODA
	signal soda_cmd_word_S				: std_logic_vector(30 downto 0)	:= (others => '0');
	signal soda_cmd_strobe_S			: std_logic := '0';
	signal soda_cmd_strobe_sodaclk_S	: std_logic := '0';	
	signal soda_cmd_pending_S			: std_logic := '0';	
	signal soda_send_cmd_S				: std_logic := '0';	
	signal start_of_superburst_S		: std_logic := '0';
	signal super_burst_nr_S				: std_logic_vector(30 downto 0)	:= (others => '0');		-- from super-burst-nr-generator
	signal soda_cmd_window_S			: std_logic := '0';
	
-- Signals
	type t_STATES is (SLEEP,RD_RDY,WR_RDY,RD_ACK,WR_ACK,DONE);
	signal CURRENT_STATE, NEXT_STATE: t_STATES;

--	signal last_packet_sent_S		: t_PACKET_TYPE_SENT	:= c_NO_PACKET;

	-- slave bus signals
	signal bus_ack_x						: std_logic;
	signal bus_ack							: std_logic;
	signal store_wr_x						: std_logic;
	signal store_wr						: std_logic;
	signal store_rd_x						: std_logic;
	signal store_rd						: std_logic;
	signal buf_bus_data_out				: std_logic_vector(31 downto 0);

	signal CTRL_STATUS_register_S		: std_logic_vector(31 downto 0);
--	signal SODA_CMD_register_i			: std_logic_vector(31 downto 0);
	signal test_line_i					: std_logic_vector(31 downto 0);

	signal reply_data_valid_S			: std_logic;
	signal expected_reply_S				: std_logic_vector(7 downto 0);
	signal reply_OK_S						: std_logic;
	signal start_calibration_S			: std_logic;

	signal calib_data_valid_S			: std_logic;
	signal calibration_time_s			: std_logic_vector(15 downto 0)	:= (others => '0');
	signal calib_register_s				: std_logic_vector(31 downto 0)	:= (others => '0');
--	signal calib_register_rst_s		: std_logic	:= '0';	-- read of calibration register resets contents to 0
	signal reply_timeout_error_S		: std_logic;
	signal channel_timeout_status_S	: std_logic;
	signal downstream_error_S			: std_logic;
	signal report_error_S				: std_logic;

	signal dead_channel_S				: std_logic;
	signal soda_reset_S					: std_logic;
	signal soda_enable_S					: std_logic;

-- PS synchronize calib_data_valid_S
	signal calib_data_valid_SYSCLK_S	: std_logic;

begin

	superburst_gen :  soda_superburst_generator
		generic map(BURST_COUNT		=> 16)
		port map(
			SODACLK						=>	SODACLK,		
			RESET							=>	soda_reset_S,
			ENABLE						=>	soda_enable_S,
			SODA_BURST_PULSE_IN		=>	SODA_BURST_PULSE_IN,
			START_OF_SUPERBURST_OUT	=>	start_of_superburst_S,
			SUPER_BURST_NR_OUT		=>	super_burst_nr_S,
			SODA_CMD_WINDOW_OUT		=> soda_cmd_window_S
		);

	packet_builder : soda_packet_builder
		port map(
			SODACLK						=>	SODACLK,
			RESET							=>	RESET,
			--Internal Connection
			LINK_PHASE_IN				=>	LINK_PHASE_IN,		--link_phase_S,	PL!
			SODA_CYCLE_IN				=> SODA_CYCLE_IN,
			SODA_CMD_WINDOW_IN		=> soda_cmd_window_S,
			SODA_CMD_STROBE_IN		=> soda_cmd_strobe_sodaclk_S,		--soda_send_cmd_S, goes with removal of SODA_CMD_FLOWCTRL
			START_OF_SUPERBURST		=> start_of_superburst_S,
			SUPER_BURST_NR_IN			=> super_burst_nr_S,
			SODA_CMD_WORD_IN			=> soda_cmd_word_S,
			EXPECTED_REPLY_OUT		=> expected_reply_S,
			SEND_TIME_CAL_OUT			=>	start_calibration_S,
			TX_DLM_PREVIEW_OUT		=>	TX_DLM_PREVIEW_OUT,
			TX_DLM_OUT					=> TX_DLM_OUT,
			TX_DLM_WORD_OUT			=> TX_DLM_WORD_OUT
		);

	src_reply_handler : soda_reply_handler
		port map(
			SODACLK						=>	SODACLK,
			RESET							=> RESET,
			CLEAR							=>	'0',
			CLK_EN						=>	'1',
			--Internal Connection
			EXPECTED_REPLY_IN			=> expected_reply_S,
			RX_DLM_IN					=> RX_DLM_IN,
			RX_DLM_WORD_IN				=> RX_DLM_WORD_IN,
			REPLY_VALID_OUT			=> reply_data_valid_S,	-- there was a reply
			REPLY_OK_OUT				=> reply_OK_S				-- the reply was as expected
		);

	src_calibration_timer : soda_calibration_timer
		port map(
			SODACLK						=>	SODACLK,
			RESET							=> RESET,
			CLEAR							=>	'0',
			CLK_EN						=>	'1',
			--Internal Connection
			START_CALIBRATION			=>	start_calibration_S,
			END_CALIBRATION			=>	reply_data_valid_S,
			VALID_OUT					=>	calib_data_valid_S,
			CALIB_TIME_OUT				=>	calibration_time_S,
			TIMEOUT_ERROR				=>	reply_timeout_error_S	-- timeout because no reply was received
		);

	--PS: synchronize calib_data_valid_S (not very important: calibration time is internal in FPGA)
	calib_data_valid_posedge_to_pulse: posedge_to_pulse 
	port map(
		IN_CLK		=> SODACLK,
		OUT_CLK		=> SYSCLK,
		CLK_EN		=> '1',
		SIGNAL_IN	=> calib_data_valid_S,
		PULSE_OUT	=> calib_data_valid_SYSCLK_S
	);

		
	sodasource_calib_timeout_proc  : process(SYSCLK)	-- converting to sysclk domain
	begin
		if rising_edge(SYSCLK) then
			if( RESET = '1' ) then
				calib_register_S								<= (others => '0');
				channel_timeout_status_S 					<= '0';
				downstream_error_S							<= '0';
				channel_timeout_status_S					<= '0';
				report_error_S									<= '0';
			elsif (calib_data_valid_SYSCLK_S = '1') then					-- calibration finished in time
				calib_register_S(15 downto 0)				<= calibration_time_S;
				channel_timeout_status_S 					<= '0';
			elsif (reply_data_valid_S = '1') then							-- the reply was correct
				channel_timeout_status_S 					<= '0';
				if (reply_OK_S = '1') then
					downstream_error_S						<= '0';
				elsif (dead_channel_S = '0') then
					downstream_error_S						<= '1';
					report_error_S								<= '1';			-- set REPORT_ERROR status-bit
				end if;
			elsif ((reply_timeout_error_S = '1') and  (reply_OK_S = '1')) then
				channel_timeout_status_S 					<= '1';
				downstream_error_S							<= '1';			-- set CALIBRATION_TIMEOUT_ERROR status-bit
				report_error_S									<= '1';			-- set REPORT_ERROR status-bit
			elsif (report_error_S = '1') then		-- check if slowcontrol wants to reset errors
				channel_timeout_status_S 					<= '0';
				downstream_error_S							<= '0';			-- set CALIBRATION_TIMEOUT_ERROR status-bit
				report_error_S									<= '0';			-- set REPORT_ERROR status-bit
			end if;
		end if;
	end process;

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
				if (SODA_READ_IN = '1') then
					NEXT_STATE <= RD_RDY;
					store_rd_x <= '1';
				elsif(SODA_WRITE_IN = '1') then
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

soda_cmd_strobe_posedge_to_pulse: posedge_to_pulse 
	port map(
		IN_CLK		=> SYSCLK,
		OUT_CLK		=> SODACLK,
		CLK_EN		=> '1',
		SIGNAL_IN	=> soda_cmd_strobe_S,
		PULSE_OUT	=> soda_cmd_strobe_sodaclk_S
	);


---------------------------------------------------------
-- Control bits                                        --
---------------------------------------------------------
	soda_reset_S		<= (RESET or CTRL_STATUS_register_S(31));
	soda_enable_S		<= CTRL_STATUS_register_S(30);
	dead_channel_S		<=	CTRL_STATUS_register_S(29);		-- slow-control can declare a channel dead
---------------------------------------------------------
-- Status bits                                         --
---------------------------------------------------------
	CTRL_STATUS_register_S(15)				<= report_error_S;
	CTRL_STATUS_register_S(14 downto 2)	<= (others => '0');
	CTRL_STATUS_register_S(1)				<= downstream_error_S;
	CTRL_STATUS_register_S(0)				<= channel_timeout_status_S;

---------------------------------------------------------
-- data handling                                       --
---------------------------------------------------------
-- For sim purposes the SOURCE gets addresses 00XX
-- register write
	THE_WRITE_REG_PROC: process( SYSCLK )
	begin
		if( rising_edge(SYSCLK) ) then
			if   ( RESET = '1' ) then
				soda_cmd_strobe_S	<= '0';
				soda_cmd_word_S	<= (others => '0');
				CTRL_STATUS_register_S(31 downto 16)	<= (30 => '1', others => '0');			-- enable soda by default
			elsif( (store_wr = '1') and (SODA_ADDR_IN = "0000") ) then
				soda_cmd_strobe_S	<= '1';
				soda_cmd_word_S	<= SODA_DATA_IN(30 downto 0);
			elsif( (store_wr = '1') and (SODA_ADDR_IN = "0011") ) then
				soda_cmd_strobe_S	<= '0';
				CTRL_STATUS_register_S(31 downto 16)		<= SODA_DATA_IN(31 downto 16);		-- use only the 16 upper bits for control
			else
				soda_cmd_strobe_S	<= '0';
			end if;
		end if;
	end process THE_WRITE_REG_PROC;


-- register read
	THE_READ_REG_PROC: process( SYSCLK )
	begin
		if( rising_edge(SYSCLK) ) then
			if   ( RESET = '1' ) then
				buf_bus_data_out		<= (others => '0');
			elsif( (store_rd = '1') and (SODA_ADDR_IN = "0000") ) then
				buf_bus_data_out		<= '0' & soda_cmd_word_S;
			elsif( (store_rd = '1') and (SODA_ADDR_IN = "0001") ) then
				buf_bus_data_out		<= '0' & super_burst_nr_S;
			elsif( (store_rd = '1') and (SODA_ADDR_IN = "0010") ) then
				buf_bus_data_out		<= calib_register_S;
			elsif( (store_rd = '1') and (SODA_ADDR_IN = "0011") ) then
				buf_bus_data_out		<= CTRL_STATUS_register_S;
			end if;
		end if;
	end process THE_READ_REG_PROC;
 
-- output signals
	LEDS_OUT			<= CTRL_STATUS_register_S(3 downto 0);
	SODA_DATA_OUT	<= buf_bus_data_out;
	SODA_ACK_OUT 	<= bus_ack;


end architecture;
