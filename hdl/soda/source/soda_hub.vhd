library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb_net16_hub_func.all; 
use work.soda_components.all;

entity soda_hub is
	port(
		SYSCLK						: in	std_logic; -- fabric clock
		SODACLK						: in	std_logic; -- recovered clock
--		TX_SODACLK					: in	t_HUB_BIT; -- tx-full  clock
		RESET							: in	std_logic; -- synchronous reset
		CLEAR							: in	std_logic; -- asynchronous reset
		CLK_EN						: in	std_logic; 

	--	SINGLE DUBPLEX UP-LINK TO THE TOP
		RXUP_DLM_IN				: in	std_logic;
		RXUP_DLM_WORD_IN		: in	std_logic_vector(7 downto 0)	:= (others => '0');
		TXUP_DLM_OUT				: out	std_logic;
		TXUP_DLM_WORD_OUT		: out	std_logic_vector(7 downto 0)	:= (others => '0');
		TXUP_DLM_PREVIEW_OUT	: out	std_logic	:= '0';	--PL!
		UPLINK_PHASE_IN			: in	std_logic	:= '0';	--PL!

	--	MULTIPLE DUPLEX DOWN-LINKS TO THE BOTTOM
		RXDN_DLM_IN				: in	t_HUB_BIT;
		RXDN_DLM_WORD_IN		: in	t_HUB_BYTE;
		TXDN_DLM_OUT				: out	t_HUB_BIT;
		TXDN_DLM_WORD_OUT		: out	t_HUB_BYTE;
		TXDN_DLM_PREVIEW_OUT	: out	t_HUB_BIT;	--PL!
		DNLINK_PHASE_IN			: in	t_HUB_BIT;	--PL!

		SODA_DATA_IN				: in	std_logic_vector(31 downto 0)	:= (others => '0');
		SODA_DATA_OUT			: out	std_logic_vector(31 downto 0)	:= (others => '0');
		SODA_ADDR_IN				: in	std_logic_vector(3 downto 0)	:= (others => '0');
		SODA_READ_IN				: in	std_logic := '0';
		SODA_WRITE_IN			: in	std_logic := '0';
		SODA_ACK_OUT				: out	std_logic := '0';
		LEDS_OUT       		   : out  std_logic_vector(3 downto 0);
		LINK_DEBUG_IN			: in	std_logic_vector(31 downto 0)	:= (others => '0')
	);
end soda_hub;

architecture Behavioral of soda_hub is

	--SODA
	signal soda_reset_S						: std_logic;
	signal soda_enable_S						: std_logic;
	
	signal soda_cmd_word_S					: std_logic_vector(30 downto 0)	:= (others => '0');
	signal soda_cmd_valid_S					: std_logic := '0';
	signal soda_cmd_strobe_S				: std_logic := '0';	-- for commands sent in a SODA package
	signal soda_cmd_strobe_sodaclk_S		: std_logic := '0';	-- for commands sent in a SODA package
	signal trb_cmd_word_S					: std_logic_vector(30 downto 0)	:= (others => '0');
	signal trb_cmd_strobe_S					: std_logic := '0';	-- for commands sent over trbnet
	signal trb_cmd_strobe_sodaclk_S		: std_logic := '0';	-- for commands sent over trbnet
--	signal soda_cmd_pending_S				: std_logic := '0';	
--	signal soda_send_cmd_S					: std_logic := '0';	
	signal start_of_superburst_S			: std_logic := '0';
	signal super_burst_nr_S					: std_logic_vector(30 downto 0)	:= (others => '0');		-- from super-burst-nr-generator
	signal crc_data_S							: std_logic_vector(7 downto 0)	:= (others => '0');
	signal crc_valid_S						: std_logic := '0';
	
-- Signals
	type STATES is (SLEEP,RD_RDY,WR_RDY,RD_ACK,WR_ACK,DONE);
	signal CURRENT_STATE, NEXT_STATE: STATES;

	signal expected_reply_S					: t_HUB_BYTE_ARRAY	:= (others => (others => '0'));
	signal reply_data_valid_S				: t_HUB_BIT_ARRAY		:= (others => '0');
	signal reply_OK_S							: t_HUB_BIT_ARRAY		:= (others => '0');
	signal recv_start_calibration_S		: std_logic := '0';
	signal send_start_calibration_S		: t_HUB_BIT_ARRAY		:= (others => '0');
	signal start_calibration_S				: t_HUB_BIT_ARRAY		:= (others => '0');
	signal stop_calibration_S				: t_HUB_BIT_ARRAY		:= (others => '0');
	signal calib_data_valid_S				: t_HUB_BIT_ARRAY		:= (others => '0');
	signal calibration_time_S				: t_HUB_WORD_ARRAY	:= (others => (others => '0'));
	signal calibration_running_S			: t_HUB_BIT_ARRAY;
--	signal calib_register_s					: t_HUB_LWORD_ARRAY	:= (others => (others => '0'));
	signal reply_timeout_error_S			: t_HUB_BIT_ARRAY		:= (others => '0');
	signal channel_timeout_status_S		: t_HUB_BIT_ARRAY		:= (others => '0');
	signal downstream_error_S				: t_HUB_BIT_ARRAY		:= (others => '0');
	signal report_error_S					: t_HUB_BIT_ARRAY;

	--signal common_reply_timeout_error_S	: std_logic;
	signal common_timeout_status_S		: std_logic;
	signal common_downstream_error_S		: std_logic;
	signal common_report_error_S			: std_logic;

	signal dead_channel_S					: t_HUB_BIT_ARRAY		:= (others => '0');

	signal COMMON_CTRL_STATUS_register_S: std_logic_vector(31 downto 0);
	signal CTRL_STATUS_register_S			: t_HUB_LWORD_ARRAY	:= (others => (others => '0'));
	
	signal TXstart_of_superburst_S		: t_HUB_BIT_ARRAY;
	signal TXsuper_burst_nr_S				: t_HUB_LWORD_ARRAY;		-- from super-burst-nr-generator
	signal TXsoda_cmd_valid_S				: t_HUB_BIT_ARRAY;
	signal TXsoda_cmd_word_S				: t_HUB_LWORD_ARRAY;
	

--	signal channel_status_S					: t_HUB_BIT_ARRAY;
--	signal status_register					: std_logic_vector(31 downto 0)	:= (others => '0');

-- slave bus signals
	signal bus_ack_x				: std_logic;
	signal bus_ack					: std_logic;
	signal store_wr_x				: std_logic;
	signal store_wr				: std_logic;
	signal store_rd_x				: std_logic;
	signal store_rd				: std_logic;
	signal buf_bus_data_out		: std_logic_vector(31 downto 0)	:= (others => '0');
	signal ledregister_i			: std_logic_vector(31 downto 0)	:= (others => '0');
--	signal txup_dlm_out_S		: std_logic;

	signal SODA_CYCLE_S			: std_logic; -- PS
begin
	
	hub_packet_handler : soda_packet_handler
		generic map(
			CLOCKSper25ns					=> 5 -- PS
		)
		port map(
			SODACLK							=>	SODACLK,
			RESET								=> RESET,
			CLEAR								=>	'0',
			CLK_EN							=>	'1',
			--Internal Connection
			START_OF_SUPERBURST_OUT		=> start_of_superburst_S,
			START_OF_CALIBRATION_OUT	=> recv_start_calibration_S,
			SUPER_BURST_NR_OUT			=> super_burst_nr_S,
			SODA_CMD_VALID_OUT			=> soda_cmd_valid_S,
			SODA_CMD_WORD_OUT				=> soda_cmd_word_S,
			SODA_CYCLE_OUT				=> SODA_CYCLE_S, -- PS
			RX_DLM_IN						=> RXUP_DLM_IN,
			RX_DLM_WORD_IN					=> RXUP_DLM_WORD_IN
		);

	hub_reply_packet_builder : soda_reply_pkt_builder		
		port map(
			SODACLK						=>	SODACLK,
			RESET							=>	RESET,
			CLEAR							=>	'0',
			CLK_EN						=> CLK_EN,
			--Internal Connection
			LINK_PHASE_IN				=> UPLINK_PHASE_IN,
			START_OF_SUPERBURST		=> start_of_superburst_S,
			SUPER_BURST_NR_IN			=> super_burst_nr_S,
			SODA_CMD_STROBE_IN		=> soda_cmd_valid_S,
			SODA_CMD_WORD_IN			=> soda_cmd_word_S,
			TX_DLM_PREVIEW_OUT		=>	TXUP_DLM_PREVIEW_OUT,
			TX_DLM_OUT					=> TXUP_DLM_OUT,
			TX_DLM_WORD_OUT			=> TXUP_DLM_WORD_OUT
		);
		
		

	channel :for i in c_HUB_CHILDREN-1 downto 0 generate
			
start_calibration_S(i)	<= send_start_calibration_S(i);

		packet_builder : soda_packet_builder
			port map(
				SODACLK						=>	SODACLK,
				RESET							=>	RESET,
				--Internal Connection
				LINK_PHASE_IN			=>	UPLINK_PHASE_IN,			--link_phase_S,	PL! 17092014    vergeten ??? of niet nodig ?
				SODA_CYCLE_IN			=> SODA_CYCLE_S, -- PS	: 40MHz cycle also required for commands !!!
				SODA_CMD_WINDOW_IN	=> '1',							-- soda-source determines the sending of a command; hub always copies
				SODA_CMD_STROBE_IN	=> soda_cmd_valid_S, -- PS: commands from source must be passed on !, my opinion:no need for hubs to send commands -- trb_cmd_strobe_S, -- PS: should be trb_cmd_strobe_sodaclk_S			--soda_cmd_valid_S,	--TXsoda_cmd_valid_S(i),
				START_OF_SUPERBURST	=> start_of_superburst_S,	--TXstart_of_superburst_S(i),
				SUPER_BURST_NR_IN		=> super_burst_nr_S,			--TXsuper_burst_nr_S(i)(30 downto 0),
				SODA_CMD_WORD_IN		=> soda_cmd_word_S, -- PS: commands from source must be passed on !, my opinion:no need for hubs to send commands -- trb_cmd_word_S,			--soda_cmd_word_S,	--TXsoda_cmd_word_S(i)(30 downto 0),
				EXPECTED_REPLY_OUT	=> expected_reply_S(i),
				SEND_TIME_CAL_OUT		=>	send_start_calibration_S(i),
				TX_DLM_PREVIEW_OUT	=>	TXDN_DLM_PREVIEW_OUT(i),
				TX_DLM_OUT				=> TXDN_DLM_OUT(i),
				TX_DLM_WORD_OUT		=> TXDN_DLM_WORD_OUT(i)
			);
				
		hub_reply_handler : soda_reply_handler
			port map(
				SODACLK						=>	SODACLK,
				RESET							=> RESET,
				CLEAR							=>	'0',
				CLK_EN						=>	'1',
				EXPECTED_REPLY_IN			=> expected_reply_S(i),
				RX_DLM_IN					=> RXDN_DLM_IN(i),
				RX_DLM_WORD_IN				=> RXDN_DLM_WORD_IN(i),
				REPLY_VALID_OUT			=> reply_data_valid_S(i),
				REPLY_OK_OUT				=> reply_OK_S(i)
			);
	 
		hub_calibration_timer : soda_calibration_timer
			port map(
				SODACLK						=>	SODACLK,
				RESET							=> RESET,
				CLEAR							=>	'0',
				CLK_EN						=>	'1',
				--Internal Connection
				START_CALIBRATION			=>	start_calibration_S(i),
				END_CALIBRATION			=>	stop_calibration_S(i),
				CALIBRATION_RUNNING		=>	calibration_running_S(i),
				VALID_OUT					=>	calib_data_valid_S(i),
				CALIB_TIME_OUT				=>	calibration_time_S(i),
				TIMEOUT_ERROR				=>	reply_timeout_error_S(i)
			);
			
		stop_calibration_S(i)			<= '1' when ((calibration_running_S(i)='1') and ((reply_data_valid_S(i) = '1') or (reply_timeout_error_S(i)='1'))) else '0';
--		channel_timeout_status_S(i) 	<= '1' when ((calibration_running_S(i)='0') and (reply_timeout_error_S(i)='1')) else '0';
--		downstream_error_S(i)			<= '1' when ((reply_data_valid_S(i) = '1') and (reply_OK_S(i) = '0')) else '0';
--		report_error_S(i)					<= '1' when ((dead_channel_S(i) = '0') and ((downstream_error_S(i)='1') or (channel_timeout_status_S(i)='1'))) else '0';
		
		sodahub_calib_timeout_proc  : process(SODACLK)
		begin
			if rising_edge(SODACLK) then
				if( RESET = '1' ) then
					downstream_error_S(i)					<= '0';
					channel_timeout_status_S(i)			<= '0';
					report_error_S(i)							<= '0';
				elsif (soda_reset_S = '1') then	-- check if slowcontrol wants to reset errors
					channel_timeout_status_S(i) 			<= '0';
					downstream_error_S(i)					<= '0';			-- set CALIBRATION_TIMEOUT_ERROR status-bit
					report_error_S(i)							<= '0';			-- reset REPORT_ERROR status-bit
				elsif (reply_data_valid_S(i) = '1') then							-- the reply was correct
					channel_timeout_status_S(i) 			<= '0';
					if (reply_OK_S(i) = '1') then
						downstream_error_S(i)				<= '0';
						report_error_S(i)						<= '0';			-- reset REPORT_ERROR status-bit
					elsif (dead_channel_S(i) = '0') then
						downstream_error_S(i)				<= '1';
						report_error_S(i)						<= '1';			-- set REPORT_ERROR status-bit
					else
						downstream_error_S(i)				<= '1';
						report_error_S(i)						<= '0';			-- reset REPORT_ERROR status-bit
					end if;
				elsif (reply_timeout_error_S(i) = '1') then --and  (reply_OK_S(i) = '1')) then
					if (dead_channel_S(i) = '0') then
						channel_timeout_status_S(i)		<= '1';
						report_error_S(i)						<= '1';			-- set REPORT_ERROR status-bit
					else
						channel_timeout_status_S(i)		<= '1';
						report_error_S(i)						<= '0';			-- reset REPORT_ERROR status-bit
					end if;
				end if;
			end if;
		end process;


		---------------------------------------------------------
		-- Control bits                                        --
		---------------------------------------------------------
		dead_channel_S(i)									<=	CTRL_STATUS_register_S(i)(29);		-- slow-control can declare a channel dead
		---------------------------------------------------------
		-- Status bits                                         --
		---------------------------------------------------------
		CTRL_STATUS_SYNC: signal_sync
			generic map(
				DEPTH => 1,
				WIDTH => 3
			)
			port map(
				RESET             => RESET,
				D_IN(0)				=> report_error_S(i),
				D_IN(1)				=> downstream_error_S(i),
				D_IN(2)				=> channel_timeout_status_S(i),
				CLK0					=> SYSCLK,
				CLK1					=> SODACLK,
				D_OUT(0)				=> CTRL_STATUS_register_S(i)(15),
				D_OUT(1)				=> CTRL_STATUS_register_S(i)(1),
				D_OUT(2)				=> CTRL_STATUS_register_S(i)(0)
			);
			
		--CTRL_STATUS_register_S(i)(15)					<= report_error_S(i);
		CTRL_STATUS_register_S(i)(14 downto 2)		<= (others => '0');
		--CTRL_STATUS_register_S(i)(1)					<= downstream_error_S(i);
		--CTRL_STATUS_register_S(i)(0)					<= channel_timeout_status_S(i);

	end generate;

	soda_reset_S											<= (RESET or COMMON_CTRL_STATUS_register_S(31));
	soda_enable_S											<= COMMON_CTRL_STATUS_register_S(30);
	common_downstream_error_S			 				<= '1' when ((downstream_error_S(0)='1') or (downstream_error_S(1)='1') or (downstream_error_S(2)='1') or (downstream_error_S(3)='1'))
																	else '0';
	common_report_error_S 								<= '1' when ((report_error_S(0)='1') or (report_error_S(1)='1') or (report_error_S(2)='1') or (report_error_S(3)='1'))
																	else '0';
	common_timeout_status_S								<= '1' when ((channel_timeout_status_S(0)='1') or (channel_timeout_status_S(1)='1') or (channel_timeout_status_S(2)='1')) or ((channel_timeout_status_S(3)='1'))
																	else '0';
	COMMON_CTRL_STATUS_register_S(15)				<= common_report_error_S;
	COMMON_CTRL_STATUS_register_S(14 downto 2)	<= (others => '0');
	COMMON_CTRL_STATUS_register_S(1)					<= common_downstream_error_S;
	COMMON_CTRL_STATUS_register_S(0)					<= common_timeout_status_S;

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

soda_cmd_strobe_posedge_to_pulse: posedge_to_pulse 
	port map(
		IN_CLK		=> SYSCLK,
		OUT_CLK		=> SODACLK,
		CLK_EN		=> '1',
		SIGNAL_IN	=> trb_cmd_strobe_S,
		PULSE_OUT	=> trb_cmd_strobe_sodaclk_S
	);

---------------------------------------------------------
-- data handling                                       --
---------------------------------------------------------
-- For sim purposes the CLIENT gets addresses 11XX
-- register write
	THE_WRITE_REG_PROC: process( SYSCLK )
	begin
		if( rising_edge(SYSCLK) ) then
			if   ( RESET = '1' ) then
				trb_cmd_strobe_S										<= '0';
				trb_cmd_word_S											<= (others => '0');
				COMMON_CTRL_STATUS_register_S(31 downto 16)	<= (30 => '1', others => '0');			-- enable soda by default
				CTRL_STATUS_register_S(0)(31 downto 16)		<= (others => '0');
				CTRL_STATUS_register_S(1)(31 downto 16)		<= (others => '0');
				CTRL_STATUS_register_S(2)(31 downto 16)		<= (others => '0');
				CTRL_STATUS_register_S(3)(31 downto 16)		<= (others => '0');
			elsif( (store_wr = '1') and (SODA_ADDR_IN = "0000") ) then
				trb_cmd_strobe_S									<= '1';
				trb_cmd_word_S										<= SODA_DATA_IN(30 downto 0);
			elsif( (store_wr = '1') and (SODA_ADDR_IN = "0011") ) then
				trb_cmd_strobe_S										<= '0';
				COMMON_CTRL_STATUS_register_S(31 downto 16)	<= SODA_DATA_IN(31 downto 16);		-- use only the 16 lower bits for control
			elsif( (store_wr = '1') and (SODA_ADDR_IN = "0100") ) then
				trb_cmd_strobe_S										<= '0';
				CTRL_STATUS_register_S(0)(31 downto 16)		<= SODA_DATA_IN(31 downto 16);		-- use only the 16 lower bits for control
			elsif( (store_wr = '1') and (SODA_ADDR_IN = "0101") ) then
				trb_cmd_strobe_S										<= '0';
				CTRL_STATUS_register_S(1)(31 downto 16)		<= SODA_DATA_IN(31 downto 16);		-- use only the 16 lower bits for control
			elsif( (store_wr = '1') and (SODA_ADDR_IN = "0110") ) then
				trb_cmd_strobe_S										<= '0';
				CTRL_STATUS_register_S(2)(31 downto 16)		<= SODA_DATA_IN(31 downto 16);		-- use only the 16 lower bits for control
			elsif( (store_wr = '1') and (SODA_ADDR_IN = "0111") ) then
				trb_cmd_strobe_S										<= '0';
				CTRL_STATUS_register_S(3)(31 downto 16)		<= SODA_DATA_IN(31 downto 16);		-- use only the 16 lower bits for control
			else
				trb_cmd_strobe_S										<= '0';
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
				buf_bus_data_out	<= '0' & trb_cmd_word_S;
			elsif( (store_rd = '1') and (SODA_ADDR_IN = "0001") ) then
				buf_bus_data_out	<= '0' & super_burst_nr_S;
			elsif( (store_rd = '1') and (SODA_ADDR_IN = "0011") ) then
				buf_bus_data_out		<= COMMON_CTRL_STATUS_register_S;
			elsif( (store_rd = '1') and (SODA_ADDR_IN = "0100") ) then
				buf_bus_data_out		<= CTRL_STATUS_register_S(0);
			elsif( (store_rd = '1') and (SODA_ADDR_IN = "0101") ) then
				buf_bus_data_out		<= CTRL_STATUS_register_S(1);
			elsif( (store_rd = '1') and (SODA_ADDR_IN = "0110") ) then
				buf_bus_data_out		<= CTRL_STATUS_register_S(2);
			elsif( (store_rd = '1') and (SODA_ADDR_IN = "0111") ) then
				buf_bus_data_out		<= CTRL_STATUS_register_S(3);
			elsif( (store_rd = '1') and (SODA_ADDR_IN = "1000") ) then
				buf_bus_data_out	<= x"0000" & calibration_time_S(0);
			elsif( (store_rd = '1') and (SODA_ADDR_IN = "1001") ) then
				buf_bus_data_out	<= x"0000" & calibration_time_S(1);
			elsif( (store_rd = '1') and (SODA_ADDR_IN = "1010") ) then
				buf_bus_data_out	<= x"0000" & calibration_time_S(2);
			elsif( (store_rd = '1') and (SODA_ADDR_IN = "1011") ) then
				buf_bus_data_out	<= x"0000" & calibration_time_S(3);
			end if;
		end if;
	end process THE_READ_REG_PROC;

--	TXUP_DLM_OUT							<= txup_dlm_out_S;
-- output signals
	LEDS_OUT									<= LEDregister_i(3 downto 0);
  
	SODA_DATA_OUT							<= buf_bus_data_out;
	SODA_ACK_OUT 							<= bus_ack;

end architecture;