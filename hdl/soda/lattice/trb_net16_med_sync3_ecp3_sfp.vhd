--Media interface for Lattice ECP3 using PCS at 2GHz

LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
--USE IEEE.numeric_std.all;
USE ieee.std_logic_unsigned.all;
USE ieee.std_logic_arith.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb3_components.all;
use work.med_sync_define.all;


entity trb_net16_med_sync3_ecp3_sfp is
  port(
    CLK                : in  std_logic; -- SerDes clock
    SYSCLK             : in  std_logic; -- fabric clock
    RESET              : in  std_logic; -- synchronous reset
    CLEAR              : in  std_logic; -- asynchronous reset
    CLK_EN             : in  std_logic;
    --Internal Connection
    MED_DATA_IN        : in  std_logic_vector(c_DATA_WIDTH-1 downto 0);
    MED_PACKET_NUM_IN  : in  std_logic_vector(c_NUM_WIDTH-1 downto 0);
    MED_DATAREADY_IN   : in  std_logic;
    MED_READ_OUT       : out std_logic;
    MED_DATA_OUT       : out std_logic_vector(c_DATA_WIDTH-1 downto 0);
    MED_PACKET_NUM_OUT : out std_logic_vector(c_NUM_WIDTH-1 downto 0);
    MED_DATAREADY_OUT  : out std_logic;
    MED_READ_IN        : in  std_logic;
    REFCLK2CORE_OUT    : out std_logic;
    CLK_RX_HALF_OUT    : out std_logic;
    CLK_RX_FULL_OUT    : out std_logic;
    --SFP Connection
    SD_RXD_P_IN        : in  std_logic;
    SD_RXD_N_IN        : in  std_logic;
    SD_TXD_P_OUT       : out std_logic;
    SD_TXD_N_OUT       : out std_logic;
	SD_DLM_IN          : in  std_logic;
	SD_DLM_WORD_IN     : in  std_logic_vector(7 downto 0);
	SD_DLM_OUT         : out std_logic;
	SD_DLM_WORD_OUT    : out  std_logic_vector(7 downto 0);
    SD_PRSNT_N_IN      : in  std_logic;  -- SFP Present ('0' = SFP in place, '1' = no SFP mounted)
    SD_LOS_IN          : in  std_logic;  -- SFP Loss Of Signal ('0' = OK, '1' = no signal)
    SD_TXDIS_OUT       : out  std_logic; -- SFP disable
    --Control Interface
    SCI_DATA_IN        : in  std_logic_vector(7 downto 0) := (others => '0');
    SCI_DATA_OUT       : out std_logic_vector(7 downto 0) := (others => '0');
    SCI_ADDR           : in  std_logic_vector(8 downto 0) := (others => '0');
    SCI_READ           : in  std_logic := '0';
    SCI_WRITE          : in  std_logic := '0';
    SCI_ACK            : out std_logic := '0';
    SCI_NACK           : out std_logic := '0';
    -- Status and control port
    STAT_OP            : out std_logic_vector (15 downto 0);
    CTRL_OP            : in  std_logic_vector (15 downto 0);
    STAT_DEBUG         : out std_logic_vector (63 downto 0);
    CTRL_DEBUG         : in  std_logic_vector (63 downto 0)
   );
end entity;

architecture trb_net16_med_sync3_ecp3_sfp_arch of trb_net16_med_sync3_ecp3_sfp is


component sfp_3sync_200_int is
 port (
------------------
-- CH0 --
-- CH1 --
-- CH2 --
    hdinp_ch2, hdinn_ch2    :   in std_logic;
    hdoutp_ch2, hdoutn_ch2   :   out std_logic;
    sci_sel_ch2    :   in std_logic;
    rxiclk_ch2    :   in std_logic;
    txiclk_ch2    :   in std_logic;
    rx_full_clk_ch2   :   out std_logic;
    rx_half_clk_ch2   :   out std_logic;
    tx_full_clk_ch2   :   out std_logic;
    tx_half_clk_ch2   :   out std_logic;
    fpga_rxrefclk_ch2    :   in std_logic;
    txdata_ch2    :   in std_logic_vector (7 downto 0);
    tx_k_ch2    :   in std_logic;
    tx_force_disp_ch2    :   in std_logic;
    tx_disp_sel_ch2    :   in std_logic;
    rxdata_ch2   :   out std_logic_vector (7 downto 0);
    rx_k_ch2   :   out std_logic;
    rx_disp_err_ch2   :   out std_logic;
    rx_cv_err_ch2   :   out std_logic;
    rx_serdes_rst_ch2_c    :   in std_logic;
    sb_felb_ch2_c    :   in std_logic;
    sb_felb_rst_ch2_c    :   in std_logic;
    tx_pcs_rst_ch2_c    :   in std_logic;
    tx_pwrup_ch2_c    :   in std_logic;
    rx_pcs_rst_ch2_c    :   in std_logic;
    rx_pwrup_ch2_c    :   in std_logic;
    rx_los_low_ch2_s   :   out std_logic;
    lsm_status_ch2_s   :   out std_logic;
    rx_cdr_lol_ch2_s   :   out std_logic;
    tx_div2_mode_ch2_c   : in std_logic;
    rx_div2_mode_ch2_c   : in std_logic;
-- CH3 --
---- Miscillaneous ports
    sci_wrdata    :   in std_logic_vector (7 downto 0);
    sci_addr    :   in std_logic_vector (5 downto 0);
    sci_rddata   :   out std_logic_vector (7 downto 0);
    sci_sel_quad    :   in std_logic;
    sci_rd    :   in std_logic;
    sci_wrn    :   in std_logic;
    fpga_txrefclk  :   in std_logic;
    tx_serdes_rst_c    :   in std_logic;
    tx_pll_lol_qd_s   :   out std_logic;
    rst_qd_c    :   in std_logic;
    serdes_rst_qd_c    :   in std_logic);

end component;


component serdes_rx_reset_sm is
port (
	rst_n			: in std_logic;
	refclkdiv2        : in std_logic;
	tx_pll_lol_qd_s	: in std_logic;
	rx_serdes_rst_ch_c: out std_logic;
	rx_cdr_lol_ch_s	: in std_logic;
	rx_los_low_ch_s	: in std_logic;
	rx_pcs_rst_ch_c	: out std_logic;
    STATE_OUT         : out std_logic_vector(3 downto 0));
end component ;
component serdes_tx_reset_sm is
port (
	rst_n 			: in std_logic;
	refclkdiv2      : in std_logic;
	tx_pll_lol_qd_s : in std_logic;
	rst_qd_c		: out std_logic;
	tx_pcs_rst_ch_c : out std_logic_vector(3 downto 0);
	STATE_OUT       : out std_logic_vector(3 downto 0)
	);
end component;

component HUB_8to16_SODA is
	port ( 
		clock                   : in std_logic;
		reset                   : in std_logic;
		data_in                 : in std_logic_vector(7 downto 0);
		char_is_k               : in std_logic;
		fifo_data               : out std_logic_vector(17 downto 0);
		fifo_full               : in std_logic;
		fifo_write              : out std_logic;
		RX_DLM                  : out std_logic;
		RX_DLM_WORD             : out std_logic_vector(7 downto 0);
		error                   : out std_logic
	);
end component;

component HUB_16to8_SODA is
	port ( 
		clock                   : in std_logic;
		reset                   : in std_logic;
		fifo_data               : in std_logic_vector(15 downto 0);
		fifo_empty              : in std_logic;
		fifo_read               : out std_logic;
		TX_DLM                  : in std_logic;
		TX_DLM_WORD             : in std_logic_vector(7 downto 0);
		data_out                : out std_logic_vector(7 downto 0);
		char_is_k               : out std_logic;
		error                   : out std_logic
	);
end component;

component HUB_SODA_clockcrossing is
	port ( 
		write_clock             : in std_logic;
		read_clock              : in std_logic;
		DLM_in                  : in std_logic;
		DLM_WORD_in             : in std_logic_vector(7 downto 0);
		DLM_out                 : out std_logic;
		DLM_WORD_out            : out std_logic_vector(7 downto 0);
		error                   : out std_logic
	);
end component;

component HUB_posedge_to_pulse is
	port (
		clock_in        : in  std_logic;
		clock_out       : in  std_logic;
		en_clk          : in  std_logic;
		signal_in       : in  std_logic;
		pulse           : out std_logic
	);
end component;

  -- Placer Directives
  attribute HGROUP : string;
  -- for whole architecture
  attribute HGROUP of trb_net16_med_sync3_ecp3_sfp_arch : architecture  is "media_interface_group";
  attribute syn_sharing : string;
  attribute syn_sharing of trb_net16_med_sync3_ecp3_sfp_arch : architecture is "off";

  signal ffc_quad_rst           : std_logic;
  --serdes connections
  signal tx_data                : std_logic_vector(7 downto 0);
  signal tx_k                   : std_logic;
  signal rx_data                : std_logic_vector(7 downto 0);
  signal rx_k                   : std_logic; 
  signal link_ok                : std_logic;  
  signal ff_txhalfclk           : std_logic;
  signal ff_txfullclk           : std_logic;
  signal ff_rxhalfclk		    : std_logic;
  signal ff_rxfullclk           : std_logic;
  --rx fifo signals
  signal fifo_rx_rd_en          : std_logic;
  signal fifo_rx_wr_en          : std_logic;
  signal fifo_rx_reset          : std_logic;
  signal fifo_rx_din            : std_logic_vector(17 downto 0);
  signal fifo_rx_dout           : std_logic_vector(17 downto 0);
  signal fifo_rx_full           : std_logic;
  signal fifo_rx_empty          : std_logic;
  --tx fifo signals
  signal fifo_tx_rd_en          : std_logic;
  signal fifo_tx_wr_en          : std_logic;
  signal fifo_tx_reset          : std_logic;
  signal fifo_tx_din            : std_logic_vector(17 downto 0);
  signal fifo_tx_dout           : std_logic_vector(17 downto 0);
  signal fifo_tx_empty          : std_logic;
  signal fifo_tx_almost_full    : std_logic;
  --rx path
  signal rx_counter             : std_logic_vector(c_NUM_WIDTH-1 downto 0);
  signal buf_med_dataready_out  : std_logic;
  signal buf_med_data_out       : std_logic_vector(c_DATA_WIDTH-1 downto 0);
  signal buf_med_packet_num_out : std_logic_vector(c_NUM_WIDTH-1 downto 0);
  signal last_rx                : std_logic_vector(8 downto 0);
  signal last_fifo_rx_empty     : std_logic;
  --link status

  signal quad_rst               : std_logic;
  signal lane_rst               : std_logic;
  signal tx_allow               : std_logic;
  signal rx_allow               : std_logic;

  signal rx_allow_q             : std_logic; -- clock domain changed signal
  signal tx_allow_q             : std_logic;
  signal buf_stat_debug         : std_logic_vector(31 downto 0);

  -- status inputs from SFP
  signal sfp_prsnt_n            : std_logic; -- synchronized input signals
  signal sfp_los                : std_logic; -- synchronized input signals

  signal buf_STAT_OP            : std_logic_vector(15 downto 0);

  signal led_counter            : unsigned(16 downto 0);
  signal rx_led                 : std_logic;
  signal tx_led                 : std_logic;

  signal reset_word_cnt         : unsigned(4 downto 0);
  signal make_trbnet_reset      : std_logic;
  signal make_trbnet_reset_q    : std_logic;
  signal send_reset_words       : std_logic;
  signal send_reset_words_q     : std_logic;
  signal send_reset_in          : std_logic;
  signal send_reset_in_qtx      : std_logic;
  signal reset_i                : std_logic;
--  signal reset_i_rx             : std_logic;
  signal pwr_up                 : std_logic;
  signal clear_n                : std_logic;
  signal trb_tx_pll_lol_qd_i    : std_logic;
 
type sci_ctrl is (IDLE, SCTRL, SCTRL_WAIT, SCTRL_WAIT2, SCTRL_FINISH, GET_WA, GET_WA_WAIT, GET_WA_WAIT2, GET_WA_FINISH);
signal sci_state                : sci_ctrl;
  signal sci_ch_i               : std_logic_vector(3 downto 0);
  signal sci_qd_i               : std_logic;
  signal sci_reg_i              : std_logic;
  signal sci_addr_i             : std_logic_vector(8 downto 0);
  signal sci_data_in_i          : std_logic_vector(7 downto 0);
  signal sci_data_out_i         : std_logic_vector(7 downto 0);
  signal sci_read_i             : std_logic;
  signal sci_write_i            : std_logic;
  signal sci_timer              : unsigned(12 downto 0) := (others => '0');
  signal trb_reset_n            : std_logic;
  signal trb_rx_serdes_rst      : std_logic;
  signal trb_rx_cdr_lol         : std_logic;
  signal trb_rx_los_low         : std_logic;
  signal trb_rx_pcs_rst         : std_logic;
  signal trb_tx_pcs_rst         : std_logic;
  signal trb_tx_pcs_rst_all     : std_logic_vector(3 downto 0);
  signal rst_qd                 : std_logic;
  signal trb_rx_fsm_state       : std_logic_vector(3 downto 0);
  signal trb_tx_fsm_state       : std_logic_vector(3 downto 0);
  
  signal trb_rx_los_low_q       : std_logic;
  signal trb_rx_cdr_lol_q       : std_logic;
  signal trb_tx_pll_lol_qd_q    : std_logic;
  signal trb_rx_cv_err_ch2      : std_logic;
  signal trb_rx_cv_err_ch2_q    : std_logic;

  signal link_tx_ok             : std_logic;
  signal link_rx_ok             : std_logic;
  signal link_tx_ok_q           : std_logic;
  signal link_rx_ok_q           : std_logic;
    
  signal wa_position_sync1      : std_logic_vector(3 downto 0);
  signal wa_position            : std_logic_vector(15 downto 0) := x"FFFF";

  signal SD_DLM_IN_S            : std_logic;
  signal SD_DLM_WORD_IN_S       : std_logic_vector(7 downto 0);
  
  attribute syn_keep : boolean;
  attribute syn_preserve : boolean;
  attribute syn_keep of led_counter : signal is true;
  attribute syn_keep of send_reset_in : signal is true;
  attribute syn_keep of reset_i : signal is true;
  attribute syn_preserve of reset_i : signal is true;

begin

--------------------------------------------------------------------------
-- Internal Lane Resets
--------------------------------------------------------------------------
  clear_n <= not clear;


PROC_RESET : process(SYSCLK)
begin
	if rising_edge(SYSCLK) then
		reset_i <= RESET;
		send_reset_in <= ctrl_op(15);
		pwr_up  <= '1'; --not CTRL_OP(i*16+14);
	end if;
end process;

--------------------------------------------------------------------------
-- Synchronizer stages
--------------------------------------------------------------------------

-- Input synchronizer for SFP_PRESENT and SFP_LOS signals (external signals from SFP)
THE_SFP_STATUS_SYNC: signal_sync
	generic map(
		DEPTH => 3,
		WIDTH => 2
	)
	port map(
		RESET    => '0',
		D_IN(0)  => sd_prsnt_n_in,
		D_IN(1)  => sd_los_in,
		CLK0     => SYSCLK,
		CLK1     => SYSCLK,
		D_OUT(0) => sfp_prsnt_n,
		D_OUT(1) => sfp_los
	);


THE_RX_K_SYNC: signal_sync
	generic map(
		DEPTH => 1,
		WIDTH => 1
	)
	port map(
		RESET             => '0',
		D_IN(0)           => send_reset_words,
		CLK0              => ff_rxfullclk,
		CLK1              => SYSCLK,
		D_OUT(0)          => send_reset_words_q
	);

THE_RESET_SYNC: HUB_posedge_to_pulse 
	port map(
		clock_in => ff_rxfullclk,
		clock_out => SYSCLK,
		en_clk => '1',
		signal_in => make_trbnet_reset,
		pulse  => make_trbnet_reset_q
	);

process(SYSCLK)
begin
	if rising_edge(SYSCLK) then
		if (tx_allow='1') and (link_tx_ok_q='1') then
			tx_allow_q <= '1';
		else
			tx_allow_q <= '0';
		end if;
		if (rx_allow='1') and (link_rx_ok_q='1') then
			rx_allow_q <= '1';
		else
			rx_allow_q <= '0';
		end if;
		link_tx_ok_q <= link_tx_ok;
		link_rx_ok_q <= link_rx_ok;
	end if;
end process;
-- synchronize link_OK 
process(CLK)
begin
	if rising_edge(CLK) then
		if trb_tx_fsm_state=x"5" then
			link_tx_ok <= '1';
		else
			link_tx_ok <= '0';
		end if;
		if (trb_rx_fsm_state=x"6") then
			link_rx_ok <= '1'; 
		else
			link_rx_ok <= '0';
		end if;
	end if;
end process;
	
THE_TX_SYNC: signal_sync
	generic map(
		DEPTH => 1,
		WIDTH => 1
	)
	port map(
		RESET    => '0',
		D_IN(0)  => send_reset_in,
		CLK0     => ff_txfullclk,
		CLK1     => ff_txfullclk,
		D_OUT(0) => send_reset_in_qtx
	);
	
THE_ERROR_SYNC: signal_sync
	generic map(
		DEPTH => 1,
		WIDTH => 4
	)
	port map(
		RESET    => '0',
		D_IN(0)  => trb_rx_los_low,
		D_IN(1)  => trb_rx_cdr_lol,
		D_IN(2)  => trb_tx_pll_lol_qd_i,
		D_IN(3)  => trb_rx_cv_err_ch2,
		CLK0     => SYSCLK,
		CLK1     => SYSCLK,
		D_OUT(0) => trb_rx_los_low_q,
		D_OUT(1) => trb_rx_cdr_lol_q,
		D_OUT(2) => trb_tx_pll_lol_qd_q,
		D_OUT(3) => trb_rx_cv_err_ch2_q
	);
	
--------------------------------------------------------------------------
-- Main control state machine, startup control for SFP
--------------------------------------------------------------------------

THE_SFP_LSM: trb_net16_lsm_sfp
	generic map (
		CHECK_FOR_CV => c_YES,
		HIGHSPEED_STARTUP => c_YES
	)
	port map(
		SYSCLK            => SYSCLK,
		RESET             => reset_i,
		CLEAR             => clear,
		SFP_MISSING_IN    => sfp_prsnt_n,
		SFP_LOS_IN        => sfp_los,
		SD_LINK_OK_IN     => link_ok, -- apparently not used
		SD_LOS_IN         => trb_rx_los_low_q, -- apparently not used
		SD_TXCLK_BAD_IN   => trb_tx_pll_lol_qd_q,
		SD_RXCLK_BAD_IN   => trb_rx_cdr_lol_q,
		SD_RETRY_IN       => '0', -- '0' = handle byte swapping in logic, '1' = simply restart link and hope
		SD_ALIGNMENT_IN	=> "01", -- should always be correct
		SD_CV_IN(0)       => trb_rx_cv_err_ch2_q,
		SD_CV_IN(1)       => trb_rx_cv_err_ch2_q,
		FULL_RESET_OUT    => quad_rst,
		LANE_RESET_OUT    => lane_rst, -- apparently not used
		TX_ALLOW_OUT      => tx_allow,
		RX_ALLOW_OUT      => rx_allow,
		SWAP_BYTES_OUT    => open,
		STAT_OP           => buf_stat_op,
		CTRL_OP           => ctrl_op,
		STAT_DEBUG        => buf_stat_debug
	);
sd_txdis_out <= quad_rst or reset_i;

--------------------------------------------------------------------------
--------------------------------------------------------------------------

-- SerDes clock output to FPGA fabric
REFCLK2CORE_OUT <= ff_rxhalfclk;
CLK_RX_HALF_OUT <= ff_rxhalfclk;
CLK_RX_FULL_OUT <= ff_rxfullclk;


THE_SERDES: sfp_3sync_200_int 
	port map(
		hdinp_ch2 => sd_rxd_p_in,                
		hdinn_ch2 => sd_rxd_n_in,                
		hdoutp_ch2 => sd_txd_p_out,              
		hdoutn_ch2 => sd_txd_n_out,              
		sci_sel_ch2 => sci_ch_i(2),
		rxiclk_ch2 => ff_rxfullclk,
		txiclk_ch2 => ff_txfullclk,
		rx_full_clk_ch2 => ff_rxfullclk,
		rx_half_clk_ch2 => ff_rxhalfclk,
		tx_full_clk_ch2 => ff_txfullclk,
		tx_half_clk_ch2 => ff_txhalfclk,
		fpga_rxrefclk_ch2 => CLK,
		txdata_ch2 => tx_data,
		tx_k_ch2 => tx_k,
		tx_force_disp_ch2 => '0',
		tx_disp_sel_ch2 => '0',
		rxdata_ch2 => rx_data,
		rx_k_ch2 => rx_k,
		rx_disp_err_ch2 => open,
		rx_cv_err_ch2 => trb_rx_cv_err_ch2,
		rx_serdes_rst_ch2_c => trb_rx_serdes_rst,
		sb_felb_ch2_c => '0',
		sb_felb_rst_ch2_c => '0',
		tx_pcs_rst_ch2_c => trb_tx_pcs_rst,
		tx_pwrup_ch2_c => '1',
		rx_pcs_rst_ch2_c => trb_rx_pcs_rst,
		rx_pwrup_ch2_c => '1',
		rx_los_low_ch2_s => trb_rx_los_low,
		lsm_status_ch2_s => link_ok,
		rx_cdr_lol_ch2_s => trb_rx_cdr_lol,
		tx_div2_mode_ch2_c => '0',   
		rx_div2_mode_ch2_c => '0',   
	---- Miscillaneous ports
		sci_wrdata => sci_data_in_i,
		sci_addr => sci_addr_i(5 downto 0),
		sci_rddata => sci_data_out_i,
		sci_sel_quad => sci_qd_i,
		sci_rd => sci_read_i,
		sci_wrn => sci_write_i,
		fpga_txrefclk => CLK,
		tx_serdes_rst_c => CLEAR,
		tx_pll_lol_qd_s => trb_tx_pll_lol_qd_i,  
		rst_qd_c => '0',
		serdes_rst_qd_c => ffc_quad_rst
	);

-------------------------------------------------------------------------
-- RX Fifo & Data output
-------------------------------------------------------------------------
THE_FIFO_SFP_TO_FPGA: trb_net_fifo_16bit_bram_dualport
	generic map(
		USE_STATUS_FLAGS => c_NO)
	port map( 
		read_clock_in => SYSCLK,
		write_clock_in => ff_rxfullclk,
		read_enable_in => fifo_rx_rd_en,
		write_enable_in => fifo_rx_wr_en,
		fifo_gsr_in => fifo_rx_reset,
		write_data_in => fifo_rx_din,
		read_data_out => fifo_rx_dout,
		full_out => fifo_rx_full,
		empty_out => fifo_rx_empty
	);
fifo_rx_reset <= '1' when (reset_i='1') or (rx_allow_q='0') else '0';
fifo_rx_rd_en <= not fifo_rx_empty;
HUB_8to16_SODA1: HUB_8to16_SODA
	port map(
		clock => ff_rxfullclk,
		reset => fifo_rx_reset,
		data_in => rx_data,
		char_is_k => rx_k,
		fifo_data => fifo_rx_din,
		fifo_full  => fifo_rx_full,
		fifo_write => fifo_rx_wr_en,
		RX_DLM => SD_DLM_OUT,
		RX_DLM_WORD => SD_DLM_WORD_OUT,
		error => open
	);
		
buf_med_data_out          <= fifo_rx_dout(15 downto 0);
buf_med_dataready_out     <= not fifo_rx_dout(17) and not fifo_rx_dout(16) and not last_fifo_rx_empty and rx_allow_q;
buf_med_packet_num_out    <= rx_counter;
med_read_out              <= tx_allow_q and not fifo_tx_almost_full;

THE_SYNC_PROC: process(SYSCLK)
begin
	if rising_edge(SYSCLK) then
		med_dataready_out     <= buf_med_dataready_out;
		med_data_out          <= buf_med_data_out;
		med_packet_num_out    <= buf_med_packet_num_out;
		if reset_i = '1' then
			med_dataready_out <= '0';
		end if;
	end if;
end process;

THE_CNT_RESET_PROC : process(ff_rxfullclk,reset_i)
	begin
		if reset_i='1' then
			send_reset_words  <= '0';
			make_trbnet_reset <= '0';
			reset_word_cnt    <= (others => '0');
		elsif rising_edge(ff_rxfullclk) then
			send_reset_words   <= '0';
			make_trbnet_reset  <= '0';
			if (rx_k='1') and (rx_data=x"FE") then
				if reset_word_cnt(4) = '0' then
					reset_word_cnt <= reset_word_cnt + 1;
				else
					send_reset_words <= '1';
				end if;
			else
				reset_word_cnt    <= (others => '0');
				make_trbnet_reset <= reset_word_cnt(4);
			end if;
		end if;
	end process;
  
--rx packet counter
---------------------
THE_RX_PACKETS_PROC: process(SYSCLK)
begin
	if( rising_edge(SYSCLK) ) then
		last_fifo_rx_empty <= fifo_rx_empty;
		if reset_i = '1' or rx_allow_q = '0' then
			rx_counter <= c_H0;
		else
			if( buf_med_dataready_out = '1' ) then
				if( rx_counter = c_max_word_number ) then
					rx_counter <= (others => '0');
				else
					rx_counter <= rx_counter + 1;
				end if;
			end if;
		end if;
	end if;
end process;
  
  
  
--TX Fifo & Data output to Serdes
---------------------
THE_FIFO_FPGA_TO_SFP: trb_net_fifo_16bit_bram_dualport
	generic map(
		USE_STATUS_FLAGS => c_NO
	)
	port map( 
		read_clock_in => ff_txfullclk,
		write_clock_in => SYSCLK,
		read_enable_in => fifo_tx_rd_en,
		write_enable_in => fifo_tx_wr_en,
		fifo_gsr_in => fifo_tx_reset,
		write_data_in => fifo_tx_din,
		read_data_out => fifo_tx_dout,
		full_out => open,
		empty_out => fifo_tx_empty,
		almost_full_out   => fifo_tx_almost_full
	);

fifo_tx_reset <= reset_i or not tx_allow_q;
fifo_tx_din   <= med_packet_num_in(2) & med_packet_num_in(0)& med_data_in;
fifo_tx_wr_en <= med_dataready_in and tx_allow_q;
 
HUB_16to8_SODA1: HUB_16to8_SODA
	port map(
		clock => ff_txfullclk,
		reset => send_reset_in_qtx,
		fifo_data => fifo_tx_dout(15 downto 0),
		fifo_empty => fifo_tx_empty,
		fifo_read => fifo_tx_rd_en,
		TX_DLM => SD_DLM_IN_S,
		TX_DLM_WORD => SD_DLM_WORD_IN_S,
		data_out => tx_data,
		char_is_k => tx_k,
		error => open
	);

HUB_SODA_clockcrossing1: HUB_SODA_clockcrossing
	port map(
		write_clock => ff_rxfullclk,
		read_clock => ff_txfullclk,
		DLM_in => SD_DLM_IN,
		DLM_WORD_in => SD_DLM_WORD_IN,
		DLM_out => SD_DLM_IN_S,
		DLM_WORD_out => SD_DLM_WORD_IN_S,
		error => open
	);



trb_reset_n <= '0' when (RESET='1') or (CLEAR='1') else '1';
ffc_quad_rst <= quad_rst;

-------------------------------------------------      
-- Reset FSM & Link states
------------------------------------------------- 
THE_RX_FSM1: rx_reset_fsm -- reset FSM for receiver channel 2 (SODA), synchronize to fiber bit with wa_position
	port map(
		RST_N               => trb_reset_n,
		RX_REFCLK           => CLK, --//ff_rxfullclk, --??CLK,
		TX_PLL_LOL_QD_S     => trb_tx_pll_lol_qd_i,
		RX_SERDES_RST_CH_C  => trb_rx_serdes_rst,
		RX_CDR_LOL_CH_S     => trb_rx_cdr_lol,
		RX_LOS_LOW_CH_S     => trb_rx_los_low,
		RX_PCS_RST_CH_C     => trb_rx_pcs_rst,
		WA_POSITION         => wa_position_sync1,
		STATE_OUT           => trb_rx_fsm_state
	);
SYNC_WA_POSITION: signal_sync
	generic map(
		DEPTH => 1,
		WIDTH => 4)
	port map(
		RESET => '0',
		D_IN(3 downto 0) => wa_position(11 downto 8),
		CLK0 => CLK, --// SYSCLK,
		CLK1 => CLK, --//ff_rxfullclk,
		D_OUT(3 downto 0) => wa_position_sync1
	);


THE_TX_FSM1: serdes_tx_reset_sm   -- original from Lattice
	port map(
		RST_N           => trb_reset_n,
		refclkdiv2      => CLK, --//??SYSCLK,
		TX_PLL_LOL_QD_S => trb_tx_pll_lol_qd_i,
		RST_QD_C        => rst_qd,
		TX_PCS_RST_CH_C => trb_tx_pcs_rst_all,
		STATE_OUT       => trb_tx_fsm_state
	);
trb_tx_pcs_rst <= trb_tx_pcs_rst_all(1);


-------------------------------------------------      
-- SCI
-------------------------------------------------      
--gives access to serdes config port from slow control and reads word alignment every ~ 40 us
PROC_SCI_CTRL: process(SYSCLK)
variable cnt : integer range 0 to 4 := 0;
begin
	if( rising_edge(SYSCLK) ) then
		SCI_ACK <= '0';
		case sci_state is
			when IDLE =>
				sci_ch_i        <= x"0";
				sci_qd_i        <= '0';
				sci_reg_i       <= '0';
				sci_read_i      <= '0';
				sci_write_i     <= '0';
				sci_timer       <= sci_timer + 1;
				if SCI_READ = '1' or SCI_WRITE = '1' then
					sci_ch_i(0)   <= not SCI_ADDR(6) and not SCI_ADDR(7) and not SCI_ADDR(8);
					sci_ch_i(1)   <=     SCI_ADDR(6) and not SCI_ADDR(7) and not SCI_ADDR(8);
					sci_ch_i(2)   <= not SCI_ADDR(6) and     SCI_ADDR(7) and not SCI_ADDR(8);
					sci_ch_i(3)   <=     SCI_ADDR(6) and     SCI_ADDR(7) and not SCI_ADDR(8);
					sci_qd_i      <= not SCI_ADDR(6) and not SCI_ADDR(7) and     SCI_ADDR(8);
					sci_reg_i     <=     SCI_ADDR(6) and not SCI_ADDR(7) and     SCI_ADDR(8);
					sci_addr_i    <= SCI_ADDR;
					sci_data_in_i <= SCI_DATA_IN;
					sci_read_i    <= SCI_READ  and not (SCI_ADDR(6) and not SCI_ADDR(7) and     SCI_ADDR(8));
					sci_write_i   <= SCI_WRITE and not (SCI_ADDR(6) and not SCI_ADDR(7) and     SCI_ADDR(8));
					sci_state     <= SCTRL;
				elsif sci_timer(sci_timer'left) = '1' then
					sci_timer     <= (others => '0');
					sci_state     <= GET_WA;
				end if;      
			when SCTRL =>
				if sci_reg_i = '1' then
					--//			SCI_DATA_OUT  <= debug_reg(8*(to_integer(unsigned(SCI_ADDR(3 downto 0))))+7 downto 8*(to_integer(unsigned(SCI_ADDR(3 downto 0)))));
					SCI_DATA_OUT  <= (others => '0');
					SCI_ACK       <= '1';
					sci_write_i   <= '0';
					sci_read_i    <= '0';
					sci_state     <= IDLE;
				else
					sci_state     <= SCTRL_WAIT;
				end if;
			when SCTRL_WAIT   =>
				sci_state       <= SCTRL_WAIT2;
			when SCTRL_WAIT2  =>
				sci_state       <= SCTRL_FINISH;
			when SCTRL_FINISH =>
				SCI_DATA_OUT    <= sci_data_out_i;
				SCI_ACK         <= '1';
				sci_write_i     <= '0';
				sci_read_i      <= '0';
				sci_state       <= IDLE;

			when GET_WA =>
				if cnt = 4 then
					cnt           := 0;
					sci_state     <= IDLE;
				else
					sci_state     <= GET_WA_WAIT;
					sci_addr_i    <= '0' & x"22";
					sci_ch_i      <= x"0";
					sci_ch_i(cnt) <= '1';
					sci_read_i    <= '1';
				end if;
			when GET_WA_WAIT  =>
				sci_state       <= GET_WA_WAIT2;
			when GET_WA_WAIT2 =>
				sci_state       <= GET_WA_FINISH;
			when GET_WA_FINISH =>
				wa_position(cnt*4+3 downto cnt*4) <= sci_data_out_i(3 downto 0);
				sci_state       <= GET_WA;    
				cnt             := cnt + 1;
		end case;

		if (SCI_READ = '1' or SCI_WRITE = '1') and sci_state /= IDLE then
			SCI_NACK <= '1';
		else
			SCI_NACK <= '0';
		end if;
	end if;
end process;
    
  

--Generate LED signals
----------------------
process(SYSCLK)
begin
	if rising_edge(SYSCLK) then
		led_counter <= led_counter + 1;
		if buf_med_dataready_out = '1' then
			rx_led <= '1';
		elsif led_counter = 0 then
			rx_led <= '0';
		end if;
		if tx_k = '0' then
			tx_led <= '1';
		elsif led_counter = 0 then
			tx_led <= '0';
		end if;
	end if;
end process;

stat_op(15)           <= send_reset_words_q;
stat_op(14)           <= buf_stat_op(14);
stat_op(13)           <= make_trbnet_reset_q;
stat_op(12)           <= '0';
stat_op(11)           <= tx_led; --tx led
stat_op(10)           <= rx_led; --rx led
stat_op(9 downto 0)   <= buf_stat_op(9 downto 0);

-- Debug output
stat_debug(7 downto 0)   <= rx_data;
stat_debug(16)           <= rx_k;
stat_debug(19 downto 18) <= (others => '0');
stat_debug(23 downto 20) <= buf_stat_debug(3 downto 0);
stat_debug(24)           <= fifo_rx_rd_en;
stat_debug(25)           <= fifo_rx_wr_en;
stat_debug(26)           <= fifo_rx_reset;
stat_debug(27)           <= fifo_rx_empty;
stat_debug(28)           <= fifo_rx_full;
stat_debug(29)           <= last_rx(8);
stat_debug(30)           <= rx_allow_q;
stat_debug(41 downto 31) <= (others => '0');
stat_debug(42)           <= SYSCLK;
stat_debug(43)           <= SYSCLK;
stat_debug(59 downto 44) <= (others => '0');
stat_debug(63 downto 60) <= buf_stat_debug(3 downto 0);


end architecture;

