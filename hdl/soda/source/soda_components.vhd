library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.STD_LOGIC_ARITH.ALL;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb_net16_hub_func.all; 


package soda_components is

	attribute syn_useioff					: boolean;
	attribute syn_keep						: boolean;
	attribute syn_preserve					: boolean;

	constant	c_PHASE_L						: std_logic	:= '0';					-- byt2word allignment of soda
	constant	c_PHASE_H						: std_logic	:= '1';					-- byt2word allignment of soda
	constant	c_HUB_CHILDREN					: natural range 1 to 4 := 4;		-- number of children per soda-hub
	constant	cSODA_CLOCK_PERIOD			: natural range 1 to 20	:= 5;		-- soda clock-period in ns
	constant	cSYS_CLOCK_PERIOD				: natural range 1 to 20	:= 10;		-- soda clock-period in ns
	constant	cSODA_CYCLE_PERIOD			: natural range 1 to 50	:= 25;		-- cycle-period at which soda transmits, in ns
	constant	cBURST_PERIOD					: natural := 2400;						-- particle-beam burst-period in ns
	constant	cSODA_COMMAND_WINDOS_SIZE	: natural range 1 to 65535 	:= 5000; -- size of the window in which soda-cmds are allowed after a superburst-pulse in ns
	constant	cSODA_CALIBRATION_TIMEOUT	: natural range 100 to 5000	:= 250;		-- soda clock-period in ns

	constant	cWINDOW_delay					: std_logic_vector(7 downto 0)	:= conv_std_logic_vector(28, 8);													-- in clock-cycles
	constant	cCLOCKS_PER_WINDOW			: std_logic_vector(15 downto 0)	:= conv_std_logic_vector((cSODA_COMMAND_WINDOS_SIZE / cSODA_CLOCK_PERIOD) - 1, 16);	-- in clock-cycles

	constant c_QUAD_DATA_WIDTH				: integer := 4*c_DATA_WIDTH;
	constant c_QUAD_NUM_WIDTH				: integer := 4*c_NUM_WIDTH;
	constant c_QUAD_MUX_WIDTH				: integer := 3; --

	subtype	t_HUB_BIT				is std_logic_vector(c_HUB_CHILDREN-1 downto 0);
	type		t_HUB_NUM				is array(c_HUB_CHILDREN-1 downto 0) of std_logic_vector(c_NUM_WIDTH-1 downto 0);
	type		t_HUB_NIBL				is array(c_HUB_CHILDREN-1 downto 0) of std_logic_vector(3 downto 0);
	type		t_HUB_BYTE				is array(c_HUB_CHILDREN-1 downto 0) of std_logic_vector(7 downto 0);
	type		t_HUB_WORD				is array(c_HUB_CHILDREN-1 downto 0) of std_logic_vector(15 downto 0);
	type		t_HUB_LWORD				is array(c_HUB_CHILDREN-1 downto 0) of std_logic_vector(31 downto 0);

	type		t_HUB_TIMER13			is array(c_HUB_CHILDREN-1 downto 0) of std_logic_vector(12 downto 0);
	type		t_HUB_TIMER19			is array(c_HUB_CHILDREN-1 downto 0) of std_logic_vector(18 downto 0);
	type		t_HUB_TIMER21			is array(c_HUB_CHILDREN-1 downto 0) of std_logic_vector(20 downto 0);

	type		t_PACKET_TYPE_SENT	is (c_NO_PACKET, c_CMD_PACKET, c_BST_PACKET);
	type		t_PACKET_TYPE_ARRAY	is array(c_HUB_CHILDREN-1 downto 0) of t_PACKET_TYPE_SENT;
	
	subtype	t_HUB_BIT_ARRAY		is std_logic_vector(c_HUB_CHILDREN-1 downto 0);
	type		t_HUB_BYTE_ARRAY		is array(c_HUB_CHILDREN-1 downto 0) of std_logic_vector(7 downto 0);
	type		t_HUB_WORD_ARRAY		is array(c_HUB_CHILDREN-1 downto 0) of std_logic_vector(15 downto 0);
	type		t_HUB_LWORD_ARRAY		is array(c_HUB_CHILDREN-1 downto 0) of std_logic_vector(31 downto 0);

	subtype	t_QUAD_BIT				is std_logic_vector(3 downto 0);
	type		t_QUAD_NIBL				is array(3 downto 0) of std_logic_vector(3 downto 0);
	type		t_QUAD_BYTE				is array(3 downto 0) of std_logic_vector(7 downto 0);
	type		t_QUAD_9WORD			is array(3 downto 0) of std_logic_vector(8 downto 0);
	type		t_QUAD_WORD				is array(3 downto 0) of std_logic_vector(15 downto 0);
	type		t_QUAD_LWORD			is array(3 downto 0) of std_logic_vector(31 downto 0);

	component soda_superburst_generator
		generic(
			BURST_COUNT : integer range 1 to 64 := 16 -- number of bursts to be counted between super-bursts
		);
		port(
			SODACLK							: in	std_logic; -- fabric clock
			RESET								: in	std_logic; -- synchronous reset 
			ENABLE							: in	std_logic; -- synchronous reset 
			SODA_BURST_PULSE_IN			: in	std_logic := '0';	-- 
			START_OF_SUPERBURST_OUT		: out	std_logic := '0';
			SUPER_BURST_NR_OUT			: out	std_logic_vector(30 downto 0) := (others => '0');
			SODA_CMD_WINDOW_OUT		: out	std_logic := '0'
			);
	end component;

	component soda_packet_builder
		port(
			SODACLK						: in	std_logic; -- fabric clock
			RESET							: in	std_logic; -- synchronous reset
			--Internal Connection
			LINK_PHASE_IN				: in	std_logic := '0';
			SODA_CYCLE_IN				: in	std_logic := '0';
			SODA_CMD_WINDOW_IN		: in	std_logic := '0';
			SODA_CMD_STROBE_IN		: in	std_logic := '0';
			START_OF_SUPERBURST		: in	std_logic := '0';
			SUPER_BURST_NR_IN			: in	std_logic_vector(30 downto 0) := (others => '0');
			SODA_CMD_WORD_IN			: in	std_logic_vector(30 downto 0) := (others => '0');		--REGIO_CTRL_REG in trbnet handler is 32 bit
			EXPECTED_REPLY_OUT		: out	std_logic_vector(7 downto 0) := (others => '0');
			SEND_TIME_CAL_OUT			: out	std_logic := '0';	-- 
			TX_DLM_PREVIEW_OUT		: out	std_logic := '0';	-- 
			TX_DLM_OUT					: out	std_logic := '0';	-- 
			TX_DLM_WORD_OUT			: out	std_logic_vector(7 downto 0) := (others => '0')
		);
	end component;

	component soda_packet_handler
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
	end component;

	component soda_d8crc8		-- crc-calculator/checker
		port( 
			CLOCK				: in std_logic; 
			RESET				: in std_logic;
			SOC_IN			: in std_logic; 
			DATA_IN			: in std_logic_vector(7 downto 0); 
			DATA_VALID_IN	: in std_logic; 
			EOC_IN			: in std_logic; 
			CRC_OUT			: out std_logic_vector(7 downto 0); 
			CRC_VALID_OUT	: out std_logic 
		);
	end component;
	
	component soda_source 	-- box containing soda_source components
		port(
			SYSCLK					: in	std_logic; -- fabric clock
			SODACLK					: in	std_logic; -- clock for data to serdes
			RESET						: in	std_logic; -- synchronous reset

			SODA_BURST_PULSE_IN	: in	std_logic := '0';	-- 
			SODA_CYCLE_IN			: in	std_logic := '0';	-- 

			RX_DLM_WORD_IN			: in	std_logic_vector(7 downto 0) := (others => '0');
			RX_DLM_IN				: in std_logic;
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
			LEDS_OUT 				: out std_logic_vector(3 downto 0)
		);
	end component;

	component soda_4source is
		port(
			SYSCLK						: in	std_logic; -- fabric clock
			SODACLK						: in	std_logic;
			RESET							: in	std_logic; -- synchronous reset
			CLEAR							: in	std_logic; -- asynchronous reset
			CLK_EN						: in	std_logic; 

			SODA_BURST_PULSE_IN		: in	std_logic := '0';
			SODA_CYCLE_IN				: in	std_logic := '0';
		--	MULTIPLE DUPLEX DOWN-LINKS
			RX_DLM_IN					: in	t_HUB_BIT;
			RX_DLM_WORD_IN				: in	t_HUB_BYTE;
			TX_DLM_OUT					: out	t_HUB_BIT;
			TX_DLM_WORD_OUT			: out	t_HUB_BYTE;
			TX_DLM_PREVIEW_OUT		: out	t_HUB_BIT;	--PL!
			LINK_PHASE_IN				: in	t_HUB_BIT;	--PL!

			SODA_DATA_IN				: in	std_logic_vector(31 downto 0)	:= (others => '0');
			SODA_DATA_OUT				: out	std_logic_vector(31 downto 0)	:= (others => '0');
			SODA_ADDR_IN				: in	std_logic_vector(3 downto 0)	:= (others => '0');
			SODA_READ_IN				: in	std_logic := '0';
			SODA_WRITE_IN				: in	std_logic := '0';
			SODA_ACK_OUT				: out	std_logic := '0';
			LEDS_OUT 		 : out std_logic_vector(3 downto 0);
			LINK_DEBUG_IN				: in	std_logic_vector(31 downto 0)	:= (others => '0')
		);
	end component;

	component soda_hub
	port(
		SYSCLK					: in	std_logic; -- fabric clock
		SODACLK					: in	std_logic; -- recovered clock
--		SODA_OUT_CLK			: in	t_HUB_BIT; -- transmit clock
		RESET						: in	std_logic; -- synchronous reset
		CLEAR						: in	std_logic; -- asynchronous reset
		CLK_EN					: in	std_logic; 

	--	SINGLE DUBPLEX UP-LINK TO THE TOP
		RXUP_DLM_IN				: in	std_logic;
		RXUP_DLM_WORD_IN		: in	std_logic_vector(7 downto 0)	:= (others => '0');
		TXUP_DLM_OUT			: out	std_logic;
		TXUP_DLM_WORD_OUT		: out	std_logic_vector(7 downto 0)	:= (others => '0');
		TXUP_DLM_PREVIEW_OUT	: out	std_logic	:= '0';	--PL!
		UPLINK_PHASE_IN		: in	std_logic	:= '0';	--PL!

	--	MULTIPLE DUPLEX DOWN-LINKS TO THE BOTTOM
		RXDN_DLM_IN				: in	t_HUB_BIT;
		RXDN_DLM_WORD_IN		: in	t_HUB_BYTE;
		TXDN_DLM_OUT			: out	t_HUB_BIT;
		TXDN_DLM_WORD_OUT		: out	t_HUB_BYTE;
		TXDN_DLM_PREVIEW_OUT	: out	t_HUB_BIT;	--PL!
		DNLINK_PHASE_IN		: in	t_HUB_BIT;	--PL!

		SODA_DATA_IN			: in	std_logic_vector(31 downto 0)	:= (others => '0');
		SODA_DATA_OUT			: out	std_logic_vector(31 downto 0)	:= (others => '0');
		SODA_ADDR_IN			: in	std_logic_vector(3 downto 0)	:= (others => '0');
		SODA_READ_IN			: in	std_logic := '0';
		SODA_WRITE_IN			: in	std_logic := '0';
		SODA_ACK_OUT			: out	std_logic := '0';
		LEDS_OUT 	 : out std_logic_vector(3 downto 0);
		LINK_DEBUG_IN			: in	std_logic_vector(31 downto 0)	:= (others => '0')
	);
	end component;

	component soda_client 	-- box containing soda_source components
		port(
			SYSCLK					: in	std_logic; -- fabric clock
			SODACLK					: in	std_logic; -- recovered clock
			RESET						: in	std_logic; -- synchronous reset
			CLEAR						: in	std_logic; -- asynchronous reset
			CLK_EN					: in	std_logic; 
			--Internal Connection
			RX_DLM_WORD_IN			: in	std_logic_vector(7 downto 0) := (others => '0');
			RX_DLM_IN				: in std_logic;
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
			LEDS_OUT 	 : out std_logic_vector(3 downto 0);
			LINK_DEBUG_IN			: in	std_logic_vector(31 downto 0)	:= (others => '0')
		);
	end component;
	
	component soda_reply_pkt_builder
		port(
			SODACLK					: in	std_logic; -- fabric clock
			RESET						: in	std_logic; -- synchronous reset
			CLEAR						: in	std_logic; -- asynchronous reset
			CLK_EN					: in	std_logic;
			--Internal Connection
			LINK_PHASE_IN			: in	std_logic := '0';	--_vector(1 downto 0) := (others => '0');
			START_OF_SUPERBURST	: in	std_logic := '0';
			SUPER_BURST_NR_IN		: in	std_logic_vector(30 downto 0) := (others => '0');
			SODA_CMD_STROBE_IN	: in	std_logic := '0';	-- 
			SODA_CMD_WORD_IN		: in	std_logic_vector(30 downto 0) := (others => '0');		--REGIO_CTRL_REG in trbnet handler is 32 bit
			TX_DLM_PREVIEW_OUT	: out	std_logic := '0';
			TX_DLM_OUT				: out	std_logic := '0';	-- 
			TX_DLM_WORD_OUT		: out	std_logic_vector(7 downto 0) := (others => '0')
		);
	end component;

	component soda_reply_handler
		port(
			SODACLK						: in	std_logic; -- fabric clock
			RESET							: in	std_logic; -- synchronous reset
			CLEAR							: in	std_logic; -- asynchronous reset
			CLK_EN						: in	std_logic;
			--Internal Connection
		--	LAST_PACKET					: in	t_PACKET_TYPE_SENT	:= c_NO_PACKET;
			EXPECTED_REPLY_IN			: in	std_logic_vector(7 downto 0) := (others => '0');
			RX_DLM_IN					: in	std_logic	:= '0';
			RX_DLM_WORD_IN				: in	std_logic_vector(7 downto 0) := (others => '0');
			REPLY_VALID_OUT			: out std_logic := '0';
			REPLY_OK_OUT				: out std_logic := '0'
		);
	end component;

	component soda_calibration_timer
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
	end component;

	component spi_flash_and_fpga_reload
		port(
			CLK_IN : in std_logic;
			RESET_IN : in std_logic;

			BUS_ADDR_IN				: in std_logic_vector(8 downto 0);
			BUS_READ_IN				: in std_logic;
			BUS_WRITE_IN			: in std_logic;
			BUS_DATAREADY_OUT		: out std_logic;
			BUS_WRITE_ACK_OUT		: out std_logic;
			BUS_UNKNOWN_ADDR_OUT	: out std_logic;
			BUS_NO_MORE_DATA_OUT	: out std_logic;
			BUS_DATA_IN				: in std_logic_vector(31 downto 0);
			BUS_DATA_OUT			: out std_logic_vector(31 downto 0);

			DO_REBOOT_IN			: in std_logic; 
			PROGRAMN					: out std_logic;

			SPI_CS_OUT				: out std_logic;
			SPI_SCK_OUT				: out std_logic;
			SPI_SDO_OUT				: out std_logic;
			SPI_SDI_IN				: in std_logic
		);
	end component;

	component soda_start_of_burst_faker
		generic(
			CLOCK_PERIOD	: natural range 1 to 20		:= 5;		-- clock-period in ns
			BURST_PERIOD	: natural range 1	to 2400	:= 2400	-- burst-period in ns
			);
		port(
			SYSCLK					: in	std_logic; -- fabric clock
			RESET						: in	std_logic; -- synchronous reset
			SODA_BURST_PULSE_OUT	: out	std_logic := '0'
			);
	end component;

	component soda_start_of_burst_control is
		generic(
			CLOCK_PERIOD			: natural range 1 to 25	:= cSODA_CLOCK_PERIOD;	-- clock-period in ns
			CYCLE_PERIOD			: natural range 5 to 50	:= cSODA_CYCLE_PERIOD;	-- cycle-period in ns
			BURST_PERIOD			: natural 					:= cBURST_PERIOD			-- burst-period in ns
			);
		port(
			SODA_CLK					: in	std_logic; -- fabric clock
			RESET						: in	std_logic; -- synchronous reset
			SODA_BURST_PULSE_OUT	: out	std_logic := '0';
			SODA_40MHZ_CYCLE_OUT	: out	std_logic := '0'
			);
	end component;

	component posedge_to_pulse
		port (
			IN_CLK			: in std_logic;
			OUT_CLK			: in std_logic;
			CLK_EN			: in std_logic;
			SIGNAL_IN		: in std_logic;
			PULSE_OUT		: out std_logic
		);
	end component;

	component med_ecp3_sfp_sync_down is
		generic(
			SERDES_NUM				: integer range 0 to 3 := 0;
			IS_SYNC_SLAVE 			: integer := c_NO); --select slave mode
		port(
			OSCCLK					: in std_logic; -- _internal_ 200 MHz reference clock
			SYSCLK					: in std_logic; -- 100 MHz main clock net, synchronous to RX clock
			RESET						: in std_logic; -- synchronous reset
			CLEAR						: in std_logic; -- asynchronous reset
	--		PCSA_REFCLKP			: in std_logic; 		-- external refclock straight into serdes
	--		PCSA_REFCLKN			: in std_logic; 		-- external refclock straight into serdes
			--Internal Connection TX
			MED_DATA_IN				: in std_logic_vector(c_DATA_WIDTH-1 downto 0);
			MED_PACKET_NUM_IN		: in std_logic_vector(c_NUM_WIDTH-1 downto 0);
			MED_DATAREADY_IN		: in std_logic;
			MED_READ_OUT			: out std_logic := '0';
			--Internal Connection RX
			MED_DATA_OUT			: out std_logic_vector(c_DATA_WIDTH-1 downto 0) := (others => '0');
			MED_PACKET_NUM_OUT	: out std_logic_vector(c_NUM_WIDTH-1 downto 0) := (others => '0');
			MED_DATAREADY_OUT		: out std_logic := '0';
			MED_READ_IN				: in std_logic;
			RX_HALF_CLK_OUT		: out std_logic := '0'; --received 100 MHz
			RX_FULL_CLK_OUT		: out std_logic := '0'; --received 200 MHz
			TX_HALF_CLK_OUT		: out std_logic := '0'; --received 100 MHz
			TX_FULL_CLK_OUT		: out std_logic := '0'; --received 200 MHz

			--Sync operation
			RX_DLM					: out std_logic := '0';
			RX_DLM_WORD				: out std_logic_vector(7 downto 0) := x"00";
			TX_DLM					: in std_logic := '0';
			TX_DLM_WORD				: in std_logic_vector(7 downto 0) := x"00";
			TX_DLM_PREVIEW_IN		: in std_logic := '0'; --PL!
			LINK_PHASE_OUT			: out std_logic := '0';	--PL!

			--SFP Connection
			SD_RXD_P_IN				: in	std_logic;
			SD_RXD_N_IN				: in	std_logic;
			SD_TXD_P_OUT			: out	std_logic;
			SD_TXD_N_OUT			: out	std_logic;
			SD_REFCLK_P_IN			: in	std_logic; --not used
			SD_REFCLK_N_IN			: in	std_logic; --not used
			SD_PRSNT_N_IN			: in	std_logic; -- SFP Present ('0' = SFP in place, '1' = no SFP mounted)
			SD_LOS_IN				: in	std_logic; -- SFP Loss Of Signal ('0' = OK, '1' = no signal)
			SD_TXDIS_OUT			: out	std_logic := '0'; -- SFP disable
			--Control Interface
			SCI_DATA_IN				: in std_logic_vector(7 downto 0) := (others => '0');
			SCI_DATA_OUT			: out std_logic_vector(7 downto 0) := (others => '0');
			SCI_ADDR					: in std_logic_vector(8 downto 0) := (others => '0');
			SCI_READ					: in std_logic := '0';
			SCI_WRITE				: in std_logic := '0';
			SCI_ACK					: out std_logic := '0';
			SCI_NACK					: out std_logic := '0';
			-- Status and control port
			STAT_OP					: out std_logic_vector (15 downto 0);
			CTRL_OP					: in std_logic_vector (15 downto 0) := (others => '0');
			STAT_DEBUG				: out std_logic_vector (63 downto 0);
			CTRL_DEBUG				: in std_logic_vector (63 downto 0) := (others => '0')
		);
	end component;

	component med_ecp3_sfp_4_sync_down
		generic(	SERDES_NUM : integer range 0 to 3 := 0;
					IS_SYNC_SLAVE : integer := c_NO); --select slave mode
		port(
			OSC_CLK					: in std_logic; -- 200 MHz reference clock
			TX_DATACLK				: in std_logic; -- 200 MHz data clock
			SYSCLK					: in std_logic; -- 100 MHz main clock net, synchronous to OSC clock
			RESET						: in std_logic; -- synchronous reset
			CLEAR						: in std_logic; -- asynchronous reset
			---------------------------------------------------------------------------------------------------------------------------------------------------------
			LINK_DISABLE_IN		: in std_logic;	-- downlinks must behave as slaves to uplink connection. Downlinks are released once unlink is established.
			---------------------------------------------------------------------------------------------------------------------------------------------------------
			--Internal Connection TX
			MED_DATA_IN				: in t_HUB_WORD;	--std_logic_vector(c_QUAD_DATA_WIDTH-1 downto 0);
			MED_PACKET_NUM_IN		: in	t_HUB_NUM;	--std_logic_vector(c_QUAD_NUM_WIDTH-1 downto 0);
			MED_DATAREADY_IN		: in std_logic_vector(3 downto 0);
			MED_READ_OUT			: out std_logic_vector(3 downto 0) := (others => '0');
			--Internal Connection RX
			MED_DATA_OUT			: out t_HUB_WORD;	-- std_logic_vector(4*c_DATA_WIDTH-1 downto 0)	:= (others => '0');
			MED_PACKET_NUM_OUT	: out t_HUB_NUM;	-- std_logic_vector(4*c_NUM_WIDTH-1 downto 0)	:= (others => '0');
			MED_DATAREADY_OUT		: out std_logic_vector(3 downto 0) 							:= (others => '0');
			MED_READ_IN				: in std_logic_vector(3 downto 0);
			RX_HALF_CLK_OUT		: out std_logic_vector(3 downto 0) := (others => '0'); --100 MHz
			RX_FULL_CLK_OUT		: out std_logic_vector(3 downto 0) := (others => '0'); --200 MHz
			TX_HALF_CLK_OUT		: out std_logic_vector(3 downto 0) := (others => '0'); --100 MHz
			TX_FULL_CLK_OUT		: out std_logic_vector(3 downto 0) := (others => '0'); --200 MHz

			--Sync operation
			RX_DLM					: out t_HUB_BIT;	--std_logic_vector(3 downto 0)			:= (others => '0');
			RX_DLM_WORD				: out	t_HUB_BYTE;	--std_logic_vector(4*8 - 1 downto 0)	:= (others => '0');
			TX_DLM					: in t_HUB_BIT;	--std_logic_vector(3 downto 0)			:= (others => '0');
			TX_DLM_WORD				: in	t_HUB_BYTE;	--std_logic_vector(4*8 - 1 downto 0)	:= (others => '0');
			TX_DLM_PREVIEW_IN		: in	t_HUB_BIT;	--std_logic_vector(3 downto 0)			:= (others => '0');	--PL!
			LINK_PHASE_OUT			: out	t_HUB_BIT;	--std_logic_vector(3 downto 0)			:= (others => '0');	--PL!

			--SFP Connection
			SD_RXD_P_IN				: in	t_HUB_BIT;	--std_logic;
			SD_RXD_N_IN				: in	t_HUB_BIT;	--std_logic;
			SD_TXD_P_OUT			: out	t_HUB_BIT;	--std_logic;
			SD_TXD_N_OUT			: out	t_HUB_BIT;	--std_logic;
			SD_REFCLK_P_IN			: in	t_HUB_BIT;	--std_logic; --not used
			SD_REFCLK_N_IN			: in	t_HUB_BIT;	--std_logic; --not used
			SD_PRSNT_N_IN			: in	t_HUB_BIT;	--std_logic; -- SFP Present ('0' = SFP in place, '1' = no SFP mounted)
			SD_LOS_IN				: in	t_HUB_BIT;	--std_logic; -- SFP Loss Of Signal ('0' = OK, '1' = no signal)
			SD_TXDIS_OUT			: out	t_HUB_BIT;	--std_logic := '0'; -- SFP disable
			--Control Interface
			SCI_DATA_IN				: in std_logic_vector(7 downto 0) := (others => '0');
			SCI_DATA_OUT			: out std_logic_vector(7 downto 0) := (others => '0');
			SCI_ADDR					: in std_logic_vector(8 downto 0) := (others => '0');
			SCI_READ					: in std_logic := '0';
			SCI_WRITE				: in std_logic := '0';
			SCI_ACK					: out std_logic := '0';
			SCI_NACK					: out std_logic := '0';
			-- Status and control port
			STAT_OP					: out	std_logic_vector (63 downto 0);
			CTRL_OP					: in	std_logic_vector (63 downto 0) := (others => '0');
			STAT_DEBUG				: out std_logic_vector (63 downto 0);
			CTRL_DEBUG				: in std_logic_vector (63 downto 0) := (others => '0')
		);
	end component;

	component med_ecp3_sfp_4_sync_down_EP is
		generic(	SERDES_NUM : integer range 0 to 3 := 0;
					IS_SYNC_SLAVE : integer := c_NO); --select slave mode
		port(
			OSC_CLK					: in std_logic; -- 200 MHz reference clock
			TX_DATACLK				: in std_logic; -- 200 MHz data clock
			SYSCLK					: in std_logic; -- 100 MHz main clock net, synchronous to OSC clock
			RESET						: in std_logic; -- synchronous reset
			CLEAR						: in std_logic; -- asynchronous reset
			---------------------------------------------------------------------------------------------------------------------------------------------------------
			LINK_DISABLE_IN		: in std_logic;	-- downlinks must behave as slaves to uplink connection. Downlinks are released once unlink is established.
			---------------------------------------------------------------------------------------------------------------------------------------------------------
			RX_HALF_CLK_OUT		: out std_logic_vector(3 downto 0) := (others => '0'); --100 MHz
			RX_FULL_CLK_OUT		: out std_logic_vector(3 downto 0) := (others => '0'); --200 MHz
			TX_HALF_CLK_OUT		: out std_logic_vector(3 downto 0) := (others => '0'); --100 MHz
			TX_FULL_CLK_OUT		: out std_logic_vector(3 downto 0) := (others => '0'); --200 MHz

			--Sync operation
			RX_DLM					: out t_HUB_BIT;	--std_logic_vector(3 downto 0)			:= (others => '0');
			RX_DLM_WORD				: out	t_HUB_BYTE;	--std_logic_vector(4*8 - 1 downto 0)	:= (others => '0');
			TX_DLM					: in t_HUB_BIT;	--std_logic_vector(3 downto 0)			:= (others => '0');
			TX_DLM_WORD				: in	t_HUB_BYTE;	--std_logic_vector(4*8 - 1 downto 0)	:= (others => '0');
			TX_DLM_PREVIEW_IN		: in	t_HUB_BIT;	--std_logic_vector(3 downto 0)			:= (others => '0');	--PL!
			LINK_PHASE_OUT			: out	t_HUB_BIT;	--std_logic_vector(3 downto 0)			:= (others => '0');	--PL!

			--SFP Connection
			SD_RXD_P_IN				: in	t_HUB_BIT;	--std_logic;
			SD_RXD_N_IN				: in	t_HUB_BIT;	--std_logic;
			SD_TXD_P_OUT			: out	t_HUB_BIT;	--std_logic;
			SD_TXD_N_OUT			: out	t_HUB_BIT;	--std_logic;
			SD_REFCLK_P_IN			: in	t_HUB_BIT;	--std_logic; --not used
			SD_REFCLK_N_IN			: in	t_HUB_BIT;	--std_logic; --not used
			SD_PRSNT_N_IN			: in	t_HUB_BIT;	--std_logic; -- SFP Present ('0' = SFP in place, '1' = no SFP mounted)
			SD_LOS_IN				: in	t_HUB_BIT;	--std_logic; -- SFP Loss Of Signal ('0' = OK, '1' = no signal)
			SD_TXDIS_OUT			: out	t_HUB_BIT;	--std_logic := '0'; -- SFP disable
			--Control Interface
			SCI_DATA_IN				: in std_logic_vector(7 downto 0) := (others => '0');
			SCI_DATA_OUT			: out std_logic_vector(7 downto 0) := (others => '0');
			SCI_ADDR					: in std_logic_vector(8 downto 0) := (others => '0');
			SCI_READ					: in std_logic := '0';
			SCI_WRITE				: in std_logic := '0';
			SCI_ACK					: out std_logic := '0';
			SCI_NACK					: out std_logic := '0'
		);
	end component;

	component med_ecp3_sfp_sync_up is
		generic(
					SERDES_NUM		: integer range 0 to 3 := 0;
					IS_SYNC_SLAVE	: integer := c_YES --select slave mode
			);
		port(
			OSCCLK					: in std_logic; -- 200 MHz reference clock
			SYSCLK					: in std_logic; -- 100 MHz main clock net, synchronous to RX clock
			RESET						: in std_logic; -- synchronous reset
			CLEAR						: in std_logic; -- asynchronous reset
			--Internal Connection TX
			MED_DATA_IN				: in std_logic_vector(c_DATA_WIDTH-1 downto 0);
			MED_PACKET_NUM_IN		: in std_logic_vector(c_NUM_WIDTH-1 downto 0);
			MED_DATAREADY_IN		: in std_logic;
			MED_READ_OUT			: out std_logic := '0';
			--Internal Connection RX
			MED_DATA_OUT			: out std_logic_vector(c_DATA_WIDTH-1 downto 0) := (others => '0');
			MED_PACKET_NUM_OUT	: out std_logic_vector(c_NUM_WIDTH-1 downto 0) := (others => '0');
			MED_DATAREADY_OUT		: out std_logic := '0';
			MED_READ_IN				: in std_logic;
			RX_HALF_CLK_OUT		: out std_logic := '0'; --received 100 MHz
			RX_FULL_CLK_OUT		: out std_logic := '0'; --received 200 MHz
			TX_HALF_CLK_OUT		: out std_logic := '0'; --pll 100 MHz
			TX_FULL_CLK_OUT		: out std_logic := '0'; --pll 200 MHz
			RX_CDR_LOL_OUT			: out std_logic := '0';	-- CLOCK_DATA RECOVERY LOSS_OF_LOCK	!PL14082014
			--Sync operation
			RX_DLM					: out std_logic := '0';
			RX_DLM_WORD				: out std_logic_vector(7 downto 0) := x"00";
			TX_DLM					: in std_logic := '0';
			TX_DLM_WORD				: in std_logic_vector(7 downto 0) := x"00";
			TX_DLM_PREVIEW_IN		: in std_logic := '0'; --PL!
			LINK_PHASE_OUT			: out	std_logic := '0';	--PL!
			LINK_READY_OUT			: out	std_logic := '0';	--PL!

			--SFP Connection
			SD_RXD_P_IN				: in std_logic;
			SD_RXD_N_IN				: in std_logic;
			SD_TXD_P_OUT			: out std_logic;
			SD_TXD_N_OUT			: out std_logic;
			SD_REFCLK_P_IN			: in std_logic; --not used
			SD_REFCLK_N_IN			: in std_logic; --not used
			SD_PRSNT_N_IN			: in std_logic; -- SFP Present ('0' = SFP in place, '1' = no SFP mounted)
			SD_LOS_IN				: in std_logic; -- SFP Loss Of Signal ('0' = OK, '1' = no signal)
			SD_TXDIS_OUT			: out std_logic := '0'; -- SFP disable
			--Control Interface
			SCI_DATA_IN				: in std_logic_vector(7 downto 0) := (others => '0');
			SCI_DATA_OUT			: out std_logic_vector(7 downto 0) := (others => '0');
			SCI_ADDR					: in std_logic_vector(8 downto 0) := (others => '0');
			SCI_READ					: in std_logic := '0';
			SCI_WRITE				: in std_logic := '0';
			SCI_ACK					: out std_logic := '0';
			SCI_NACK					: out std_logic := '0';
			-- Status and control port
			STAT_OP					: out std_logic_vector (15 downto 0);
			CTRL_OP					: in std_logic_vector (15 downto 0) := (others => '0');
			STAT_DEBUG				: out std_logic_vector (63 downto 0);
			CTRL_DEBUG				: in std_logic_vector (63 downto 0) := (others => '0')
		);
	end component;

	component soda_only_ecp3_sfp_sync_up
		generic(	SERDES_NUM				: integer range 0 to 3 := 0;
					IS_SYNC_SLAVE			: integer := c_YES); --select slave mode
		port(
			OSCCLK					: in std_logic; -- 200 MHz reference clock
			SYSCLK					: in std_logic; -- 100 MHz main clock net, synchronous to RX clock
			RESET : in std_logic; -- synchronous reset
			CLEAR : in std_logic; -- asynchronous reset

			RX_HALF_CLK_OUT : out std_logic := '0'; --received 100 MHz
			RX_FULL_CLK_OUT : out std_logic := '0'; --received 200 MHz
			TX_HALF_CLK_OUT : out std_logic := '0'; --received 100 MHz
			TX_FULL_CLK_OUT : out std_logic := '0'; --received 200 MHz
			RX_CDR_LOL_OUT			: out std_logic := '0';	-- CLOCK_DATA RECOVERY LOSS_OF_LOCK 	!PL14082014

			--Sync operation
			RX_DLM : out std_logic := '0';
			RX_DLM_WORD : out std_logic_vector(7 downto 0) := x"00";
			TX_DLM : in std_logic := '0';
			TX_DLM_WORD : in std_logic_vector(7 downto 0) := x"00";
			TX_DLM_PREVIEW_IN		: in std_logic := '0'; --PL!
			LINK_PHASE_OUT			: out	std_logic := '0';	--PL!
			LINK_READY_OUT			: out	std_logic := '0';	--PL!

			--SFP Connection
			SD_RXD_P_IN : in std_logic;
			SD_RXD_N_IN : in std_logic;
			SD_TXD_P_OUT : out std_logic;
			SD_TXD_N_OUT : out std_logic;
			SD_REFCLK_P_IN : in std_logic; --not used
			SD_REFCLK_N_IN : in std_logic; --not used
			SD_PRSNT_N_IN : in std_logic; -- SFP Present ('0' = SFP in place, '1' = no SFP mounted)
			SD_LOS_IN : in std_logic; -- SFP Loss Of Signal ('0' = OK, '1' = no signal)
			SD_TXDIS_OUT : out std_logic := '0'; -- SFP disable
			--Control Interface
			SCI_DATA_IN : in std_logic_vector(7 downto 0) := (others => '0');
			SCI_DATA_OUT : out std_logic_vector(7 downto 0) := (others => '0');
			SCI_ADDR : in std_logic_vector(8 downto 0) := (others => '0');
			SCI_READ : in std_logic := '0';
			SCI_WRITE : in std_logic := '0';
			SCI_ACK : out std_logic := '0';
			SCI_NACK : out std_logic := '0'
		);
	end component;

	component med_ecp3_sfp_4_soda is
		generic(	SERDES_NUM : integer range 0 to 3 := 0;
					IS_SYNC_SLAVE : integer := c_NO); -- hub downlink is NO slave
		port(
			OSC_CLK					: in std_logic; -- 200 MHz reference clock
			TX_DATACLK				: in std_logic; -- 200 MHz data clock
			SYSCLK					: in std_logic; -- 100 MHz main clock net, synchronous to OSC clock
			RESET						: in std_logic; -- synchronous reset
			CLEAR						: in std_logic; -- asynchronous reset
			---------------------------------------------------------------------------------------------------------------------------------------------------------
--			LINK_DISABLE_IN		: in std_logic;	-- downlinks must behave as slaves to uplink connection. Downlinks are released once unlink is established.
			---------------------------------------------------------------------------------------------------------------------------------------------------------
			RX_HALF_CLK_OUT		: out std_logic_vector(3 downto 0) := (others => '0'); --100 MHz
			RX_FULL_CLK_OUT		: out std_logic_vector(3 downto 0) := (others => '0'); --200 MHz
			TX_HALF_CLK_OUT		: out std_logic_vector(3 downto 0) := (others => '0'); --100 MHz
			TX_FULL_CLK_OUT		: out std_logic_vector(3 downto 0) := (others => '0'); --200 MHz

			--Sync operation
			RX_DLM_OUT					: out	t_HUB_BIT;	--std_logic_vector(3 downto 0)			:= (others => '0');
			RX_DLM_WORD_OUT				: out	t_HUB_BYTE;	--std_logic_vector(4*8 - 1 downto 0)	:= (others => '0');
			TX_DLM_IN					: in	t_HUB_BIT;	--std_logic_vector(3 downto 0)			:= (others => '0');
			TX_DLM_WORD_IN				: in	t_HUB_BYTE;	--std_logic_vector(4*8 - 1 downto 0)	:= (others => '0');
			TX_DLM_PREVIEW_IN		: in	t_HUB_BIT;	--std_logic_vector(3 downto 0)			:= (others => '0');	--PL!
			LINK_PHASE_OUT			: out	t_HUB_BIT;	--std_logic_vector(3 downto 0)			:= (others => '0');	--PL!

			--SFP Connection 
			SD_RXD_P_IN				: in	t_HUB_BIT;	--std_logic_vector(3 downto 0);
			SD_RXD_N_IN				: in	t_HUB_BIT;	--std_logic_vector(3 downto 0);
			SD_TXD_P_OUT			: out	t_HUB_BIT;	--std_logic_vector(3 downto 0);
			SD_TXD_N_OUT			: out	t_HUB_BIT;	--std_logic_vector(3 downto 0);
			SD_REFCLK_P_IN			: in	t_HUB_BIT;	--std_logic; --not used
			SD_REFCLK_N_IN			: in	t_HUB_BIT;	--std_logic; --not used
			SD_PRSNT_N_IN			: in	t_HUB_BIT;	--std_logic; -- SFP Present ('0' = SFP in place, '1' = no SFP mounted)
			SD_LOS_IN				: in	t_HUB_BIT;	--std_logic; -- SFP Loss Of Signal ('0' = OK, '1' = no signal)
			SD_TXDIS_OUT			: out	t_HUB_BIT;	--std_logic := '0'; -- SFP disable
			--Control Interface
			SCI_DATA_IN				: in std_logic_vector(7 downto 0) := (others => '0');
			SCI_DATA_OUT			: out std_logic_vector(7 downto 0) := (others => '0');
			SCI_ADDR					: in std_logic_vector(8 downto 0) := (others => '0');
			SCI_READ					: in std_logic := '0';
			SCI_WRITE				: in std_logic := '0';
			SCI_ACK					: out std_logic := '0';
			SCI_NACK					: out std_logic := '0'--;
			-- Status and control port
--			STAT_OP					: out	t_HUB_WORD;	--std_logic_vector (15 downto 0);
--			CTRL_OP					: in	t_HUB_WORD;	--std_logic_vector (15 downto 0) := (others => '0');
--			STAT_DEBUG				: out std_logic_vector (63 downto 0);
--			CTRL_DEBUG				: in std_logic_vector (63 downto 0) := (others => '0')
		);
	end component;

	component Cu_trb_net16_soda_syncUP_ecp3_sfp
		port(
			OSCCLK					: in std_logic; -- 200 MHz reference clock
			SYSCLK					: in std_logic; -- 100 MHz main clock net, synchronous to RX clock
			RESET						: in std_logic; -- synchronous reset
			CLEAR						: in std_logic; -- asynchronous reset
			--Internal Connection TX
			MED_DATA_IN				: in std_logic_vector(c_DATA_WIDTH-1 downto 0);
			MED_PACKET_NUM_IN		: in std_logic_vector(c_NUM_WIDTH-1 downto 0);
			MED_DATAREADY_IN		: in std_logic;
			MED_READ_OUT			: out std_logic := '0';
			--Internal Connection RX
			MED_DATA_OUT			: out std_logic_vector(c_DATA_WIDTH-1 downto 0) := (others => '0');
			MED_PACKET_NUM_OUT	: out std_logic_vector(c_NUM_WIDTH-1 downto 0) := (others => '0');
			MED_DATAREADY_OUT		: out std_logic := '0';
			MED_READ_IN				: in std_logic;

			--Copper SFP Connection
			CU_RXD_P_IN				: in std_logic;
			CU_RXD_N_IN				: in std_logic;
			CU_TXD_P_OUT			: out std_logic;
			CU_TXD_N_OUT			: out std_logic;
			CU_PRSNT_N_IN			: in std_logic; -- SFP Present ('0' = SFP in place, '1' = no SFP mounted)
			CU_LOS_IN				: in std_logic; -- SFP Loss Of Signal ('0' = OK, '1' = no signal)
			CU_TXDIS_OUT			: out std_logic := '0'; -- SFP disable
			--Fiber/sync SFP Connection
			SYNC_RX_HALF_CLK_OUT	: out std_logic := '0'; --received 100 MHz
			SYNC_RX_FULL_CLK_OUT	: out std_logic := '0'; --received 200 MHz
			SYNC_TX_HALF_CLK_OUT	: out std_logic := '0'; --received 100 MHz
			SYNC_TX_FULL_CLK_OUT	: out std_logic := '0'; --received 200 MHz
			SYNC_TX_DLM_IN			: in  std_logic;
			SYNC_TX_DLM_WORD_IN	: in  std_logic_vector(7 downto 0);
			SYNC_RX_DLM_OUT		: out  std_logic;
			SYNC_RX_DLM_WORD_OUT	: out  std_logic_vector(7 downto 0);
			SYNC_RXD_P_IN			: in std_logic;
			SYNC_RXD_N_IN			: in std_logic;
			SYNC_TXD_P_OUT			: out std_logic;
			SYNC_TXD_N_OUT			: out std_logic;
			SYNC_PRSNT_N_IN		: in std_logic; -- SFP Present ('0' = SFP in place, '1' = no SFP mounted)
			SYNC_LOS_IN				: in std_logic; -- SFP Loss Of Signal ('0' = OK, '1' = no signal)
			SYNC_TXDIS_OUT			: out std_logic := '0'; -- SFP disable
			--Control Interface
			SCI_DATA_IN				: in std_logic_vector(7 downto 0) := (others => '0');
			SCI_DATA_OUT			: out std_logic_vector(7 downto 0) := (others => '0');
			SCI_ADDR					: in std_logic_vector(8 downto 0) := (others => '0');
			SCI_READ					: in std_logic := '0';
			SCI_WRITE				: in std_logic := '0';
			SCI_ACK					: out std_logic := '0';
			SCI_NACK					: out std_logic := '0';
			-- Status and control port
			STAT_OP					: out std_logic_vector (15 downto 0);
			CTRL_OP					: in std_logic_vector (15 downto 0) := (others => '0');
			STAT_DEBUG				: out std_logic_vector (63 downto 0);
			CTRL_DEBUG				: in std_logic_vector (63 downto 0) := (others => '0')
		);
	end component;

	component Cu_trb_net16_soda_sync_ecp3_sfp
		port(
			OSCCLK					: in std_logic; -- 200 MHz reference clock
			SYSCLK					: in std_logic; -- 100 MHz main clock net, synchronous to RX clock
			RESET						: in std_logic; -- synchronous reset
			CLEAR						: in std_logic; -- asynchronous reset
			--Internal Connection TX
			MED_DATA_IN				: in std_logic_vector(c_DATA_WIDTH-1 downto 0);
			MED_PACKET_NUM_IN		: in std_logic_vector(c_NUM_WIDTH-1 downto 0);
			MED_DATAREADY_IN		: in std_logic;
			MED_READ_OUT			: out std_logic := '0';
			--Internal Connection RX
			MED_DATA_OUT			: out std_logic_vector(c_DATA_WIDTH-1 downto 0) := (others => '0');
			MED_PACKET_NUM_OUT	: out std_logic_vector(c_NUM_WIDTH-1 downto 0) := (others => '0');
			MED_DATAREADY_OUT		: out std_logic := '0';
			MED_READ_IN				: in std_logic;

			--Copper SFP Connection
			CU_RXD_P_IN				: in std_logic;
			CU_RXD_N_IN				: in std_logic;
			CU_TXD_P_OUT			: out std_logic;
			CU_TXD_N_OUT			: out std_logic;
			CU_PRSNT_N_IN			: in std_logic; -- SFP Present ('0' = SFP in place, '1' = no SFP mounted)
			CU_LOS_IN				: in std_logic; -- SFP Loss Of Signal ('0' = OK, '1' = no signal)
			CU_TXDIS_OUT			: out std_logic := '0'; -- SFP disable
			--Fiber/sync SFP Connection
			SYNC_RX_HALF_CLK_OUT	: out std_logic := '0'; --received 100 MHz
			SYNC_RX_FULL_CLK_OUT	: out std_logic := '0'; --received 200 MHz
			SYNC_TX_HALF_CLK_OUT	: out std_logic := '0'; --received 100 MHz
			SYNC_TX_FULL_CLK_OUT	: out std_logic := '0'; --received 200 MHz
			SYNC_RX_DLM_IN			: in  std_logic;
			SYNC_RX_DLM_WORD_IN	: in  std_logic_vector(7 downto 0);
			SYNC_TX_DLM_OUT		: out  std_logic;
			SYNC_TX_DLM_WORD_OUT	: out  std_logic_vector(7 downto 0);
			SYNC_RXD_P_IN			: in std_logic;
			SYNC_RXD_N_IN			: in std_logic;
			SYNC_TXD_P_OUT			: out std_logic;
			SYNC_TXD_N_OUT			: out std_logic;
			SYNC_PRSNT_N_IN		: in std_logic; -- SFP Present ('0' = SFP in place, '1' = no SFP mounted)
			SYNC_LOS_IN				: in std_logic; -- SFP Loss Of Signal ('0' = OK, '1' = no signal)
			SYNC_TXDIS_OUT			: out std_logic := '0'; -- SFP disable
			--Control Interface
			SCI_DATA_IN				: in std_logic_vector(7 downto 0) := (others => '0');
			SCI_DATA_OUT			: out std_logic_vector(7 downto 0) := (others => '0');
			SCI_ADDR					: in std_logic_vector(8 downto 0) := (others => '0');
			SCI_READ					: in std_logic := '0';
			SCI_WRITE				: in std_logic := '0';
			SCI_ACK					: out std_logic := '0';
			SCI_NACK					: out std_logic := '0';
			-- Status and control port
			STAT_OP					: out std_logic_vector (15 downto 0);
			CTRL_OP					: in std_logic_vector (15 downto 0) := (others => '0');
			STAT_DEBUG				: out std_logic_vector (63 downto 0);
			CTRL_DEBUG				: in std_logic_vector (63 downto 0) := (others => '0')
		);
	end component;

	component soda_tx_control
		port(
			CLK_200								: in std_logic;
			CLK_100								: in std_logic;
			RESET_IN								: in std_logic;

			TX_DATA_IN							: in std_logic_vector(15 downto 0);
			TX_PACKET_NUMBER_IN				: in std_logic_vector(2 downto 0);
			TX_WRITE_IN							: in std_logic;
			TX_READ_OUT							: out std_logic;

			TX_DATA_OUT							: out std_logic_vector( 7 downto 0);
			TX_K_OUT								: out std_logic;

			REQUEST_RETRANSMIT_IN			: in std_logic := '0';
			REQUEST_POSITION_IN				: in std_logic_vector( 7 downto 0) := (others => '0');

			START_RETRANSMIT_IN				: in std_logic := '0';
			START_POSITION_IN					: in std_logic_vector( 7 downto 0) := (others => '0');
			--send_dlm: 200 MHz, 1 clock strobe, data valid until next DLM
			TX_DLM_PREVIEW_IN					: in std_logic := '0';
			SEND_DLM								: in std_logic := '0';
			SEND_DLM_WORD						: in std_logic_vector( 7 downto 0) := (others => '0');

			SEND_LINK_RESET_IN				: in std_logic := '0';
			TX_ALLOW_IN							: in std_logic := '0';
			RX_ALLOW_IN							: in std_logic := '0';
			LINK_PHASE_OUT						: out std_logic := '0';

			DEBUG_OUT							: out std_logic_vector(31 downto 0);
			STAT_REG_OUT						: out std_logic_vector(31 downto 0)
		);
		end component;

	component soda_cmd_window_generator
		generic(		CLOCK_PERIOD			: natural range 1 to 20	:= cSODA_CLOCK_PERIOD;				-- clock-period in ns
						COMMAND_WINDOS_SIZE	: natural range 1 to 65335 := cSODA_COMMAND_WINDOS_SIZE		-- command window size in ns 
					);
		port(
			SODACLK						: in	std_logic; -- fabric clock
			RESET							: in	std_logic; -- synchronous reset
			START_OF_SUPERBURST_IN	: in	std_logic := '0';	-- 
			SODA_CMD_WINDOW_OUT		: out	std_logic := '0'
			);
	end component;

	component soda_clockscaler
		port(
			CLK						: in	std_logic; -- fabric clock
			RESET						: in	std_logic; -- synchronous reset
			CLOCK_ENABLE_OUT		: out	std_logic := '0';
			CLOCK_OUT				: out	std_logic
			);
	end component;

component DCS		generic(DCSMODE : string :="POS");
		port (
			CLK0						: in std_logic ;
			CLK1						: in std_logic ;
			SEL						: in std_logic ;
			DCSOUT					: out std_logic
		);
	end component;

	component dff_re
		Port (
			rst						: in STD_LOGIC;
			clk						: in STD_LOGIC;
			enable					: in STD_LOGIC;
			d							: in STD_LOGIC_VECTOR;
			q							: out STD_LOGIC_VECTOR;
			data_valid				: out	STD_LOGIC
		);
	end component;

	component soda_only_ecp3_sfp_4_sync_down is
		generic(	SERDES_NUM : integer range 0 to 3 := 0;
					IS_SYNC_SLAVE : integer := c_NO); --select slave mode
		port(
			OSC_CLK					: in  std_logic; -- 200 MHz reference clock
			TX_DATACLK				: in  std_logic; -- 200 MHz data clock
			SYSCLK					: in  std_logic; -- 100 MHz main clock net, synchronous to OSC clock
			RESET						: in  std_logic; -- synchronous reset
			CLEAR						: in  std_logic; -- asynchronous reset
			---------------------------------------------------------------------------------------------------------------------------------------------------------
	--		LINK_DISABLE_IN		: in  std_logic;	-- downlinks must behave as slaves to uplink connection. Downlinks are released once unlink is established.
			---------------------------------------------------------------------------------------------------------------------------------------------------------
			RX_HALF_CLK_OUT		: out std_logic_vector(3 downto 0) := (others => '0');  --100 MHz
			RX_FULL_CLK_OUT		: out std_logic_vector(3 downto 0) := (others => '0');  --200 MHz
			TX_HALF_CLK_OUT		: out std_logic_vector(3 downto 0) := (others => '0');  --100 MHz
			TX_FULL_CLK_OUT		: out std_logic_vector(3 downto 0) := (others => '0');  --200 MHz

			--Sync operation
			RX_DLM_OUT				: out	t_HUB_BIT;	--std_logic_vector(3 downto 0)			:= (others => '0');
			RX_DLM_WORD_OUT		: out	t_HUB_BYTE;	--std_logic_vector(4*8 - 1 downto 0)	:= (others => '0');
			TX_DLM_IN				: in	t_HUB_BIT;	--std_logic_vector(3 downto 0)			:= (others => '0');
			TX_DLM_WORD_IN			: in	t_HUB_BYTE;	--std_logic_vector(4*8 - 1 downto 0)	:= (others => '0');
			TX_DLM_PREVIEW_IN		: in	t_HUB_BIT;	--std_logic_vector(3 downto 0)			:= (others => '0');	--PL!
			LINK_PHASE_OUT			: out	t_HUB_BIT;	--std_logic_vector(3 downto 0)			:= (others => '0');	--PL!

			--SFP Connection 
			SD_RXD_P_IN				: in	t_HUB_BIT;	--std_logic_vector(3 downto 0);
			SD_RXD_N_IN				: in	t_HUB_BIT;	--std_logic_vector(3 downto 0);
			SD_TXD_P_OUT			: out	t_HUB_BIT;	--std_logic_vector(3 downto 0);
			SD_TXD_N_OUT			: out	t_HUB_BIT;	--std_logic_vector(3 downto 0);
			SD_REFCLK_P_IN			: in	t_HUB_BIT;	--std_logic;  --not used
			SD_REFCLK_N_IN			: in	t_HUB_BIT;	--std_logic;  --not used
			SD_PRSNT_N_IN			: in	t_HUB_BIT;	--std_logic;  -- SFP Present ('0' = SFP in place, '1' = no SFP mounted)
			SD_LOS_IN				: in	t_HUB_BIT;	--std_logic;  -- SFP Loss Of Signal ('0' = OK, '1' = no signal)
			SD_TXDIS_OUT			: out	t_HUB_BIT;	--std_logic := '0'; -- SFP disable
			--Control Interface
			SCI_DATA_IN				: in  std_logic_vector(7 downto 0) := (others => '0');
			SCI_DATA_OUT			: out std_logic_vector(7 downto 0) := (others => '0');
			SCI_ADDR					: in  std_logic_vector(8 downto 0) := (others => '0');
			SCI_READ					: in  std_logic := '0';
			SCI_WRITE				: in  std_logic := '0';
			SCI_ACK					: out std_logic := '0';
			SCI_NACK					: out std_logic := '0'
		);
	end component;

end package;
