--Media interface for Lattice ECP3 using PCS at 2GHz, RX clock == TX clock
--For fully synchronized FPGAs only!
--Either 200 MHz input for 2GBit or 125 MHz for 2.5GBit.
--system clock can be 100 MHz or 125 MHz

LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
--use ieee.numeric_std.all;
USE ieee.std_logic_unsigned.all;
USE ieee.std_logic_arith.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb3_components.all;
use work.med_sync_define.all;


entity trb_net16_med_syncfull_ecp3_sfp is
  port(
    CLK          : in  std_logic; -- SerDes clock
    SYSCLK       : in  std_logic; -- fabric clock
    RESET        : in  std_logic; -- synchronous reset
    CLEAR        : in  std_logic; -- asynchronous reset
    CLK_EN       : in  std_logic;
    --Internal Connection
    MED_DATA_IN        : in  std_logic_vector(4*c_DATA_WIDTH-1 downto 0);
    MED_PACKET_NUM_IN  : in  std_logic_vector(4*c_NUM_WIDTH-1 downto 0);
    MED_DATAREADY_IN   : in  std_logic_vector(3 downto 0);
    MED_READ_OUT       : out std_logic_vector(3 downto 0);
    MED_DATA_OUT       : out std_logic_vector(4*c_DATA_WIDTH-1 downto 0);
    MED_PACKET_NUM_OUT : out std_logic_vector(4*c_NUM_WIDTH-1 downto 0);
    MED_DATAREADY_OUT  : out std_logic_vector(3 downto 0);
    MED_READ_IN        : in  std_logic_vector(3 downto 0);
    REFCLK2CORE_OUT    : out std_logic;
    --SFP Connection
    SD_RXD_P_IN        : in  std_logic_vector(3 downto 0);
    SD_RXD_N_IN        : in  std_logic_vector(3 downto 0);
    SD_TXD_P_OUT       : out std_logic_vector(3 downto 0);
    SD_TXD_N_OUT       : out std_logic_vector(3 downto 0);
    SD_REFCLK_P_IN     : in  std_logic;
    SD_REFCLK_N_IN     : in  std_logic;
    SD_PRSNT_N_IN      : in  std_logic_vector(3 downto 0); -- SFP Present ('0' = SFP in place, '1' = no SFP mounted)
    SD_LOS_IN          : in  std_logic_vector(3 downto 0); -- SFP Loss Of Signal ('0' = OK, '1' = no signal)
    SD_TXDIS_OUT       : out std_logic_vector(3 downto 0); -- SFP disable
	--Synchronous signals
	RX_DLM             : out std_logic_vector(3 downto 0);
	RX_DLM_WORD        : out std_logic_vector(4*8-1 downto 0);
	TX_DLM             : in std_logic_vector(3 downto 0);
	TX_DLM_WORD        : in std_logic_vector(4*8-1 downto 0);
    --Control Interface
    SCI_DATA_IN        : in  std_logic_vector(7 downto 0) := (others => '0');
    SCI_DATA_OUT       : out std_logic_vector(7 downto 0) := (others => '0');
    SCI_ADDR           : in  std_logic_vector(8 downto 0) := (others => '0');
    SCI_READ           : in  std_logic := '0';
    SCI_WRITE          : in  std_logic := '0';
    SCI_ACK            : out std_logic := '0';
    -- Status and control port
    STAT_OP            : out  std_logic_vector (4*16-1 downto 0);
    CTRL_OP            : in  std_logic_vector (4*16-1 downto 0);
    STAT_DEBUG         : out  std_logic_vector (64*4-1 downto 0);
    CTRL_DEBUG         : in  std_logic_vector (63 downto 0)
   );
end entity;

architecture arch_ecp3_sfp_4 of trb_net16_med_syncfull_ecp3_sfp is
 
component serdes_sync_200_full is
  port (
------------------
-- CH0 --
    hdinp_ch0, hdinn_ch0    :   in std_logic;
    hdoutp_ch0, hdoutn_ch0   :   out std_logic;
    sci_sel_ch0    :   in std_logic;
    rxiclk_ch0    :   in std_logic;
    txiclk_ch0    :   in std_logic;
    rx_full_clk_ch0   :   out std_logic;
    rx_half_clk_ch0   :   out std_logic;
    tx_full_clk_ch0   :   out std_logic;
    tx_half_clk_ch0   :   out std_logic;
    fpga_rxrefclk_ch0    :   in std_logic;
    txdata_ch0    :   in std_logic_vector (7 downto 0);
    tx_k_ch0    :   in std_logic;
    tx_force_disp_ch0    :   in std_logic;
    tx_disp_sel_ch0    :   in std_logic;
    rxdata_ch0   :   out std_logic_vector (7 downto 0);
    rx_k_ch0   :   out std_logic;
    rx_disp_err_ch0   :   out std_logic;
    rx_cv_err_ch0   :   out std_logic;
    rx_serdes_rst_ch0_c    :   in std_logic;
    sb_felb_ch0_c    :   in std_logic;
    sb_felb_rst_ch0_c    :   in std_logic;
    tx_pcs_rst_ch0_c    :   in std_logic;
    tx_pwrup_ch0_c    :   in std_logic;
    rx_pcs_rst_ch0_c    :   in std_logic;
    rx_pwrup_ch0_c    :   in std_logic;
    rx_los_low_ch0_s   :   out std_logic;
    lsm_status_ch0_s   :   out std_logic;
    rx_cdr_lol_ch0_s   :   out std_logic;
    tx_div2_mode_ch0_c   : in std_logic;
    rx_div2_mode_ch0_c   : in std_logic;
-- CH1 --
    hdinp_ch1, hdinn_ch1    :   in std_logic;
    hdoutp_ch1, hdoutn_ch1   :   out std_logic;
    sci_sel_ch1    :   in std_logic;
    rxiclk_ch1    :   in std_logic;
    txiclk_ch1    :   in std_logic;
    rx_full_clk_ch1   :   out std_logic;
    rx_half_clk_ch1   :   out std_logic;
    tx_full_clk_ch1   :   out std_logic;
    tx_half_clk_ch1   :   out std_logic;
    fpga_rxrefclk_ch1    :   in std_logic;
    txdata_ch1    :   in std_logic_vector (7 downto 0);
    tx_k_ch1    :   in std_logic;
    tx_force_disp_ch1    :   in std_logic;
    tx_disp_sel_ch1    :   in std_logic;
    rxdata_ch1   :   out std_logic_vector (7 downto 0);
    rx_k_ch1   :   out std_logic;
    rx_disp_err_ch1   :   out std_logic;
    rx_cv_err_ch1   :   out std_logic;
    rx_serdes_rst_ch1_c    :   in std_logic;
    sb_felb_ch1_c    :   in std_logic;
    sb_felb_rst_ch1_c    :   in std_logic;
    tx_pcs_rst_ch1_c    :   in std_logic;
    tx_pwrup_ch1_c    :   in std_logic;
    rx_pcs_rst_ch1_c    :   in std_logic;
    rx_pwrup_ch1_c    :   in std_logic;
    rx_los_low_ch1_s   :   out std_logic;
    lsm_status_ch1_s   :   out std_logic;
    rx_cdr_lol_ch1_s   :   out std_logic;
    tx_div2_mode_ch1_c   : in std_logic;
    rx_div2_mode_ch1_c   : in std_logic;
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
    hdinp_ch3, hdinn_ch3    :   in std_logic;
    hdoutp_ch3, hdoutn_ch3   :   out std_logic;
    sci_sel_ch3    :   in std_logic;
    rxiclk_ch3    :   in std_logic;
    txiclk_ch3    :   in std_logic;
    rx_full_clk_ch3   :   out std_logic;
    rx_half_clk_ch3   :   out std_logic;
    tx_full_clk_ch3   :   out std_logic;
    tx_half_clk_ch3   :   out std_logic;
    fpga_rxrefclk_ch3    :   in std_logic;
    txdata_ch3    :   in std_logic_vector (7 downto 0);
    tx_k_ch3    :   in std_logic;
    tx_force_disp_ch3    :   in std_logic;
    tx_disp_sel_ch3    :   in std_logic;
    rxdata_ch3   :   out std_logic_vector (7 downto 0);
    rx_k_ch3   :   out std_logic;
    rx_disp_err_ch3   :   out std_logic;
    rx_cv_err_ch3   :   out std_logic;
    rx_serdes_rst_ch3_c    :   in std_logic;
    sb_felb_ch3_c    :   in std_logic;
    sb_felb_rst_ch3_c    :   in std_logic;
    tx_pcs_rst_ch3_c    :   in std_logic;
    tx_pwrup_ch3_c    :   in std_logic;
    rx_pcs_rst_ch3_c    :   in std_logic;
    rx_pwrup_ch3_c    :   in std_logic;
    rx_los_low_ch3_s   :   out std_logic;
    lsm_status_ch3_s   :   out std_logic;
    rx_cdr_lol_ch3_s   :   out std_logic;
    tx_div2_mode_ch3_c   : in std_logic;
    rx_div2_mode_ch3_c   : in std_logic;
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
    tx_sync_qd_c    :   in std_logic;
    rst_qd_c    :   in std_logic;
    serdes_rst_qd_c    :   in std_logic);
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
  attribute HGROUP of arch_ecp3_sfp_4 : architecture  is "media_interface_group";
  attribute syn_sharing : string;
  attribute syn_sharing of arch_ecp3_sfp_4 : architecture is "off";
  type array4x8_type is array(3 downto 0) of std_logic_vector(7 downto 0);
  type array_4x4_type is array(3 downto 0) of std_logic_vector(3 downto 0);


  signal refck2core             : std_logic;
  --reset signals
  signal ffc_quad_rst           : std_logic;
  --serdes connections
  signal tx_data                : array4x8_type;
  signal tx_k                   : std_logic_vector(4*1-1 downto 0);
  signal rx_data                : array4x8_type;
  signal rx_k                   : std_logic_vector(4*1-1 downto 0);  
  signal link_ok                : std_logic_vector(4*1-1 downto 0);
  signal link_ok_q              : std_logic_vector(4*1-1 downto 0);
  --rx fifo signals
  signal fifo_rx_rd_en          : std_logic_vector(4*1-1 downto 0);
  signal fifo_rx_wr_en          : std_logic_vector(4*1-1 downto 0);
  signal fifo_rx_reset          : std_logic_vector(4*1-1 downto 0);
  signal fifo_rx_din            : std_logic_vector(4*18-1 downto 0);
  signal fifo_rx_dout           : std_logic_vector(4*18-1 downto 0);
  signal fifo_rx_full           : std_logic_vector(4*1-1 downto 0);
  signal fifo_rx_empty          : std_logic_vector(4*1-1 downto 0);
  --tx fifo signals
  signal fifo_tx_rd_en          : std_logic_vector(4*1-1 downto 0);
  signal fifo_tx_wr_en          : std_logic_vector(4*1-1 downto 0);
  signal fifo_tx_reset          : std_logic_vector(4*1-1 downto 0);
  signal fifo_tx_din            : std_logic_vector(4*18-1 downto 0);
  signal fifo_tx_dout           : std_logic_vector(4*18-1 downto 0);
  signal fifo_tx_full           : std_logic_vector(4*1-1 downto 0);
  signal fifo_tx_empty          : std_logic_vector(4*1-1 downto 0);
  signal fifo_tx_almost_full    : std_logic_vector(4*1-1 downto 0);
  --rx path
  signal rx_counter             : std_logic_vector(4*3-1 downto 0);
  signal buf_med_dataready_out  : std_logic_vector(4*1-1 downto 0);
  signal buf_med_data_out       : std_logic_vector(4*16-1 downto 0);
  signal buf_med_packet_num_out : std_logic_vector(4*3-1 downto 0);
  signal last_fifo_rx_empty     : std_logic_vector(4*1-1 downto 0);
  --tx path
  signal last_fifo_tx_empty     : std_logic_vector(4*1-1 downto 0);
  --link status
  signal fifo_rx_full_q         : std_logic_vector(4*1-1 downto 0);

  signal rx_rst_n               : std_logic;
  signal tx_rst_n               : std_logic;
  
  signal quad_rst               : std_logic_vector(4*1-1 downto 0);
  signal lane_rst               : std_logic_vector(4*1-1 downto 0);
  signal tx_allow               : std_logic_vector(4*1-1 downto 0);
  signal rx_allow               : std_logic_vector(4*1-1 downto 0);
  signal link_tx_ok             : std_logic_vector(4*1-1 downto 0);
  signal link_rx_ok             : std_logic_vector(4*1-1 downto 0);
  signal link_tx_ok_q           : std_logic_vector(4*1-1 downto 0);
  signal link_rx_ok_q           : std_logic_vector(4*1-1 downto 0);
  signal rx_fsm_state           : array_4x4_type;
  signal tx_fsm_state           : array_4x4_type;

  signal rx_allow_q             : std_logic_vector(4*1-1 downto 0); -- clock domain changed signal
  signal tx_allow_q             : std_logic_vector(4*1-1 downto 0);
  signal buf_stat_debug         : std_logic_vector(4*32-1 downto 0);

  -- status inputs from SFP
  signal sfp_prsnt_n            : std_logic_vector(4*1-1 downto 0);
  signal sfp_los                : std_logic_vector(4*1-1 downto 0);

  signal buf_STAT_OP            : std_logic_vector(4*16-1 downto 0);

  signal led_counter            : unsigned(16 downto 0);
  signal rx_led                 : std_logic_vector(4*1-1 downto 0);
  signal tx_led                 : std_logic_vector(4*1-1 downto 0);

  type arr5_t is array (0 to 3) of unsigned(4 downto 0);
  signal reset_word_cnt         : arr5_t;
  signal make_trbnet_reset      : std_logic_vector(4*1-1 downto 0);
  signal make_trbnet_reset_q    : std_logic_vector(4*1-1 downto 0);
  signal send_reset_words       : std_logic_vector(4*1-1 downto 0);
  signal send_reset_words_q     : std_logic_vector(4*1-1 downto 0);
  signal send_reset_in          : std_logic_vector(4*1-1 downto 0);
  signal reset_i                : std_logic;
  signal reset_i_rx             : std_logic_vector(4*1-1 downto 0);
  signal pwr_up                 : std_logic_vector(4*1-1 downto 0);
  signal rx_serdes_rst          : std_logic_vector(4*1-1 downto 0);
  signal tx_pcs_rst             : std_logic_vector(4*1-1 downto 0);
  signal rx_pcs_rst             : std_logic_vector(4*1-1 downto 0);
  signal rst_qd                 : std_logic;
  signal rst_qd_S               : std_logic_vector(3 downto 0);
  signal rx_los_low             : std_logic_vector(3 downto 0);
  signal rx_los_low_q           : std_logic_vector(3 downto 0);
  signal rx_cdr_lol             : std_logic_vector(3 downto 0);
  signal rx_cdr_lol_q           : std_logic_vector(3 downto 0);
  signal rx_cv_err              : std_logic_vector(3 downto 0);
  signal rx_cv_err_q            : std_logic_vector(3 downto 0);
  signal tx_pll_lol             : std_logic;
  signal tx_pll_lol_q           : std_logic;
	
  signal tx_sync_qd_c           : std_logic;
  signal tx_sync_qd_c_S         : std_logic;

  signal rx_fullclk_i           : std_logic_vector(3 downto 0);
  signal tx_fullclk_i           : std_logic_vector(3 downto 0);
  
  signal sci_ch_i               : std_logic_vector(3 downto 0);
  signal sci_addr_i             : std_logic_vector(8 downto 0);
  signal sci_data_in_i          : std_logic_vector(7 downto 0);
  signal sci_data_out_i         : std_logic_vector(7 downto 0);
  signal sci_read_i             : std_logic;
  signal sci_write_i            : std_logic;
  signal sci_write_shift_i      : std_logic_vector(2 downto 0);
  signal sci_read_shift_i       : std_logic_vector(2 downto 0);

  signal RX_DLM_S               : std_logic_vector(3 downto 0);
  signal RX_DLM_WORD_S          : std_logic_vector(8*4-1 downto 0);

  attribute syn_keep : boolean;
  attribute syn_preserve : boolean;
  attribute syn_keep of led_counter : signal is true;
  attribute syn_keep of send_reset_in : signal is true;
  attribute syn_keep of reset_i : signal is true;
  attribute syn_preserve of reset_i : signal is true;
  attribute syn_keep of SCI_DATA_OUT : signal is true;
  attribute syn_preserve of SCI_DATA_OUT : signal is true;

begin

--------------------------------------------------------------------------
-- Internal Resets
--------------------------------------------------------------------------
PROC_RESET : process(SYSCLK)
begin
	if rising_edge(SYSCLK) then
		reset_i <= RESET;
		pwr_up  <= x"F"; --not CTRL_OP(i*16+14);
	end if;
end process;

THE_SENDRESET_SYNC: signal_sync
	generic map(
		DEPTH => 1,
		WIDTH => 4
	)
	port map(
		RESET => '0',
		D_IN(0) => ctrl_op(15),
		D_IN(1) => ctrl_op(15+16),
		D_IN(2) => ctrl_op(15+32),
		D_IN(3) => ctrl_op(15+48),
		CLK0 => SYSCLK,
		CLK1 => CLK,
		D_OUT(0) => send_reset_in(0),
		D_OUT(1) => send_reset_in(1),
		D_OUT(2) => send_reset_in(2),
		D_OUT(3) => send_reset_in(3)
	);

--------------------------------------------------------------------------
-- Synchronizer stages
--------------------------------------------------------------------------

-- Input synchronizer for SFP_PRESENT and SFP_LOS signals (external signals from SFP)
THE_SFPSIGNALS_SYNC: signal_sync
	generic map(
		DEPTH => 1,
		WIDTH => 29
	)
	port map(
		RESET             => '0',
		D_IN(3 downto 0)  => SD_PRSNT_N_IN,
		D_IN(7 downto 4)  => SD_LOS_IN,
		D_IN(11 downto 8) => send_reset_words,
		D_IN(15 downto 12) => link_ok,
		D_IN(19 downto 16) => rx_los_low,
		D_IN(23 downto 20) => rx_cdr_lol,
		D_IN(27 downto 24) => rx_cv_err,
		D_IN(28) => tx_pll_lol,
		CLK0              => SYSCLK,
		CLK1              => SYSCLK,
		D_OUT(3 downto 0) => sfp_prsnt_n,
		D_OUT(7 downto 4) => sfp_los,
		D_OUT(11 downto 8)=> send_reset_words_q,
		D_OUT(15 downto 12) => link_ok_q,
		D_OUT(19 downto 16) => rx_los_low_q,
		D_OUT(23 downto 20) => rx_cdr_lol_q,
		D_OUT(27 downto 24) => rx_cv_err_q,
		D_OUT(28) => tx_pll_lol_q
	);

	
process(SYSCLK)
begin
	if rising_edge(SYSCLK) then
		for i in 0 to 3 loop
			if (tx_allow(i)='1') and (link_tx_ok_q(i)='1') then
				tx_allow_q(i) <= '1';
			else
				tx_allow_q(i) <= '0';
			end if;
			if (rx_allow(i)='1') and (link_rx_ok_q(i)='1') then
				rx_allow_q(i) <= '1';
			else
				rx_allow_q(i) <= '0';
			end if;
		end loop;
		link_tx_ok_q <= link_tx_ok;
		link_rx_ok_q <= link_rx_ok;
	end if;
end process;

process(CLK)
begin
	if rising_edge(CLK) then
		for i in 0 to 3 loop
			if tx_fsm_state(i)=x"5" then
				link_tx_ok(i) <= '1';
			else
				link_tx_ok(i) <= '0';
			end if;
			if (rx_fsm_state(i)=x"6") then
				link_rx_ok(i) <= '1';
			else
				link_rx_ok(i) <= '0';
			end if;
		end loop;
		fifo_rx_full_q <= fifo_rx_full;
	end if;
end process;


--------------------------------------------------------------------------
-- Main control state machine, startup control for SFP
--------------------------------------------------------------------------
gen_LSM : for i in 0 to 3 generate
	THE_SFP_LSM: trb_net16_lsm_sfp
		generic map (
			HIGHSPEED_STARTUP => c_YES
		)  
		port map(
			SYSCLK => SYSCLK,
			RESET => reset_i,
			CLEAR => clear,
			SFP_MISSING_IN => sfp_prsnt_n(i),
			SFP_LOS_IN => sfp_los(i),
			SD_LINK_OK_IN => link_ok_q(i),
			SD_LOS_IN => rx_los_low_q(i),
			SD_TXCLK_BAD_IN => tx_pll_lol_q,
			SD_RXCLK_BAD_IN => rx_cdr_lol_q(i),
			SD_RETRY_IN => '0', -- '0' = handle byte swapping in logic, '1' = simply restart link and hope
			SD_ALIGNMENT_IN => "01", -- no swapping
			SD_CV_IN(0) => rx_cv_err_q(i),
			SD_CV_IN(1) => rx_cv_err_q(i),
			FULL_RESET_OUT => quad_rst(i),
			LANE_RESET_OUT => lane_rst(i),
			TX_ALLOW_OUT => tx_allow(i),
			RX_ALLOW_OUT => rx_allow(i),
			SWAP_BYTES_OUT => open,
			STAT_OP => buf_stat_op(i*16+15 downto i*16),
			CTRL_OP => ctrl_op(i*16+15 downto i*16),
			STAT_DEBUG => buf_stat_debug(i*32+31 downto i*32)
		);

	sd_txdis_out(i) <= quad_rst(i) or reset_i;
	ffc_quad_rst <= quad_rst(0);

end generate;


PROC_SCI : process(SYSCLK)
begin
	if rising_edge(SYSCLK) then
		if SCI_READ = '1' or SCI_WRITE = '1' then
			sci_ch_i(0)   <= not SCI_ADDR(6) and not SCI_ADDR(7) and not SCI_ADDR(8);
			sci_ch_i(1)   <=     SCI_ADDR(6) and not SCI_ADDR(7) and not SCI_ADDR(8);
			sci_ch_i(2)   <= not SCI_ADDR(6) and     SCI_ADDR(7) and not SCI_ADDR(8);
			sci_ch_i(3)   <=     SCI_ADDR(6) and     SCI_ADDR(7) and not SCI_ADDR(8);
			sci_addr_i    <= SCI_ADDR;
			sci_data_in_i <= SCI_DATA_IN;
		end if;
		sci_read_shift_i  <= sci_read_shift_i(1 downto 0) & SCI_READ;
		sci_write_shift_i <= sci_write_shift_i(1 downto 0) & SCI_WRITE;
		SCI_DATA_OUT      <= sci_data_out_i;
	end if;
end process;

sci_write_i <= or_all(sci_write_shift_i);
sci_read_i <= or_all(sci_read_shift_i);
SCI_ACK <= sci_write_shift_i(2) or sci_read_shift_i(2);
  
THE_SERDES: serdes_sync_200_full 
	port map(
-- CH0 --
		HDINP_CH0           => sd_rxd_p_in(0),
		HDINN_CH0           => sd_rxd_n_in(0),
		HDOUTP_CH0          => sd_txd_p_out(0),
		HDOUTN_CH0          => sd_txd_n_out(0),
		SCI_SEL_CH0         => sci_ch_i(0),
		RXICLK_CH0          => rx_fullclk_i(0), -- CLK, -- ?
		TXICLK_CH0          => CLK,
		RX_FULL_CLK_CH0     => rx_fullclk_i(0),
		RX_HALF_CLK_CH0     => open,
		TX_FULL_CLK_CH0     => tx_fullclk_i(0),
		TX_HALF_CLK_CH0     => open,
		FPGA_RXREFCLK_CH0   => CLK,
		TXDATA_CH0          => tx_data(0),
		TX_K_CH0            => tx_k(0),
		TX_FORCE_DISP_CH0   => '0',
		TX_DISP_SEL_CH0     => '0',
		RXDATA_CH0          => rx_data(0),
		RX_K_CH0            => rx_k(0),
		RX_DISP_ERR_CH0     => open,
		RX_CV_ERR_CH0       => rx_cv_err(0),
		rx_serdes_rst_ch0_c => rx_serdes_rst(0),
		SB_FELB_CH0_C       => '0', --loopback enable
		SB_FELB_RST_CH0_C   => '0', --loopback reset
		tx_pcs_rst_ch0_c    => tx_pcs_rst(0),
		TX_PWRUP_CH0_C      => '1', --tx power up
		rx_pcs_rst_ch0_c    => rx_pcs_rst(0),
		RX_PWRUP_CH0_C      => '1', --rx power up
		RX_LOS_LOW_CH0_S    => rx_los_low(0),
		LSM_STATUS_CH0_S    => link_ok(0),
		RX_CDR_LOL_CH0_S    => rx_cdr_lol(0),
		TX_DIV2_MODE_CH0_C  => '0', --full rate
		RX_DIV2_MODE_CH0_C  => '0', --full rate
-- CH1 --
		HDINP_CH1           => sd_rxd_p_in(1),
		HDINN_CH1           => sd_rxd_n_in(1),
		HDOUTP_CH1          => sd_txd_p_out(1),
		HDOUTN_CH1          => sd_txd_n_out(1),
		SCI_SEL_CH1         => sci_ch_i(1),
		RXICLK_CH1          => rx_fullclk_i(1), -- CLK, -- ?
		TXICLK_CH1          => CLK,
		RX_FULL_CLK_CH1     => rx_fullclk_i(1),
		RX_HALF_CLK_CH1     => open,
		TX_FULL_CLK_CH1     => tx_fullclk_i(1),
		TX_HALF_CLK_CH1     => open,
		FPGA_RXREFCLK_CH1   => CLK,
		TXDATA_CH1          => tx_data(1),
		TX_K_CH1            => tx_k(1),
		TX_FORCE_DISP_CH1   => '0',
		TX_DISP_SEL_CH1     => '0',
		RXDATA_CH1          => rx_data(1),
		RX_K_CH1            => rx_k(1),
		RX_DISP_ERR_CH1     => open,
		RX_CV_ERR_CH1       => rx_cv_err(1),
		rx_serdes_rst_ch1_c => rx_serdes_rst(1),
		SB_FELB_CH1_C       => '0', --loopback enable
		SB_FELB_RST_CH1_C   => '0', --loopback reset
		tx_pcs_rst_ch1_c => tx_pcs_rst(1),
		TX_PWRUP_CH1_C      => '1', --tx power up
		rx_pcs_rst_ch1_c    => rx_pcs_rst(1),
		RX_PWRUP_CH1_C      => '1', --rx power up
		RX_LOS_LOW_CH1_S    => rx_los_low(1),
		LSM_STATUS_CH1_S    => link_ok(1),
		RX_CDR_LOL_CH1_S    => rx_cdr_lol(1),
		TX_DIV2_MODE_CH1_C  => '0', --full rate
		RX_DIV2_MODE_CH1_C  => '0', --full rate
-- CH2 --
		HDINP_CH2           => sd_rxd_p_in(2),
		HDINN_CH2           => sd_rxd_n_in(2),
		HDOUTP_CH2          => sd_txd_p_out(2),
		HDOUTN_CH2          => sd_txd_n_out(2),
		SCI_SEL_CH2         => sci_ch_i(2),
		RXICLK_CH2          => rx_fullclk_i(2), -- CLK, -- ?
		TXICLK_CH2          => CLK,
		RX_FULL_CLK_CH2     => rx_fullclk_i(2),
		RX_HALF_CLK_CH2     => open,
		TX_FULL_CLK_CH2     => tx_fullclk_i(2),
		TX_HALF_CLK_CH2     => open,
		FPGA_RXREFCLK_CH2   => CLK,
		TXDATA_CH2          => tx_data(2),
		TX_K_CH2            => tx_k(2),
		TX_FORCE_DISP_CH2   => '0',
		TX_DISP_SEL_CH2     => '0',
		RXDATA_CH2          => rx_data(2),
		RX_K_CH2            => rx_k(2),
		RX_DISP_ERR_CH2     => open,
		RX_CV_ERR_CH2       => rx_cv_err(2),
		rx_serdes_rst_ch2_c => rx_serdes_rst(2),
		SB_FELB_CH2_C       => '0', --loopback enable
		SB_FELB_RST_CH2_C   => '0', --loopback reset
		tx_pcs_rst_ch2_c => tx_pcs_rst(2),
		TX_PWRUP_CH2_C      => '1', --tx power up
		rx_pcs_rst_ch2_c    => rx_pcs_rst(2),
		RX_PWRUP_CH2_C      => '1', --rx power up
		RX_LOS_LOW_CH2_S    => rx_los_low(2),
		LSM_STATUS_CH2_S    => link_ok(2),
		RX_CDR_LOL_CH2_S    => rx_cdr_lol(2),
		TX_DIV2_MODE_CH2_C  => '0', --full rate
		RX_DIV2_MODE_CH2_C  => '0', --full rate
-- CH3 --
		HDINP_CH3           => sd_rxd_p_in(3),
		HDINN_CH3           => sd_rxd_n_in(3),
		HDOUTP_CH3          => sd_txd_p_out(3),
		HDOUTN_CH3          => sd_txd_n_out(3),
		SCI_SEL_CH3         => sci_ch_i(3),
		RXICLK_CH3          => rx_fullclk_i(3),  -- CLK, -- ?
		TXICLK_CH3          => CLK,
		RX_FULL_CLK_CH3     => rx_fullclk_i(3),
		RX_HALF_CLK_CH3     => open,
		TX_FULL_CLK_CH3     => tx_fullclk_i(3),
		TX_HALF_CLK_CH3     => open,
		FPGA_RXREFCLK_CH3   => CLK,
		TXDATA_CH3          => tx_data(3),
		TX_K_CH3            => tx_k(3),
		TX_FORCE_DISP_CH3   => '0',
		TX_DISP_SEL_CH3     => '0',
		RXDATA_CH3          => rx_data(3),
		RX_K_CH3            => rx_k(3),          
		RX_DISP_ERR_CH3     => open,
		RX_CV_ERR_CH3       => rx_cv_err(3),
		rx_serdes_rst_ch3_c => rx_serdes_rst(3),
		SB_FELB_CH3_C       => '0', --loopback enable
		SB_FELB_RST_CH3_C   => '0', --loopback reset
		tx_pcs_rst_ch3_c => tx_pcs_rst(3),
		TX_PWRUP_CH3_C      => '1', --tx power up
		rx_pcs_rst_ch3_c    => rx_pcs_rst(3),
		RX_PWRUP_CH3_C      => '1', --rx power up
		RX_LOS_LOW_CH3_S    => rx_los_low(3),
		LSM_STATUS_CH3_S    => link_ok(3),
		RX_CDR_LOL_CH3_S    => rx_cdr_lol(3),
		TX_DIV2_MODE_CH3_C  => '0', --full rate
		RX_DIV2_MODE_CH3_C  => '0', --full rate
---- Miscillaneous ports
		SCI_WRDATA          => sci_data_in_i,
		SCI_RDDATA          => sci_data_out_i,
		SCI_ADDR            => sci_addr_i(5 downto 0),
		SCI_SEL_QUAD        => sci_addr_i(8),
		SCI_RD              => sci_read_i,
		SCI_WRN             => sci_write_i,      
		FPGA_TXREFCLK       => CLK,
		TX_SERDES_RST_C     => CLEAR,
		TX_PLL_LOL_QD_S     => tx_pll_lol,    
		TX_SYNC_QD_C        => tx_sync_qd_c,
		rst_qd_c            => rst_qd,
		SERDES_RST_QD_C     => ffc_quad_rst
	);
	

-------------------------------------------------      
-- Reset FSM & Link states
-------------------------------------------------
process(CLK)
begin
	if (rising_edge(CLK)) then 
		if rst_qd_S/="0000" then
			rst_qd <= '1';
		else
			rst_qd <= '0';
		end if;
		tx_sync_qd_c <= tx_sync_qd_c_S;
	end if;
end process;

process(CLK)
variable prev_state_ok : std_logic_vector(0 to 3) := "0000";
variable cntr : std_logic_vector(3 downto 0) := "0000";
begin
	if (rising_edge(CLK)) then 
		if ((tx_fsm_state(0)=x"5") and (prev_state_ok(0)='0')) or
		   ((tx_fsm_state(1)=x"5") and (prev_state_ok(1)='0')) or
		   ((tx_fsm_state(2)=x"5") and (prev_state_ok(2)='0')) or
		   ((tx_fsm_state(3)=x"5") and (prev_state_ok(3)='0')) then
			tx_sync_qd_c_S <= not tx_sync_qd_c_S;
			cntr := (others => '0');
		else -- double toggle, necessary?
			if cntr="1110" then
				tx_sync_qd_c_S <= not tx_sync_qd_c_S;
			end if;
			if cntr/="1111" then
				cntr := cntr+1;
			end if;			
		end if;
		for i in 0 to 3 loop
			if (tx_fsm_state(i)=x"5") then
				prev_state_ok(i) := '1';
			else
				prev_state_ok(i) := '0';
			end if;
		end loop;
	end if;
end process;

GENERATE_RESET_FSM: for i in 0 to 3 generate  

THE_RX_FSM : rx_reset_fsm
	port map(
		RST_N               => rx_rst_n,
		RX_REFCLK           => CLK,
		TX_PLL_LOL_QD_S     => tx_pll_lol,
		RX_SERDES_RST_CH_C  => rx_serdes_rst(i),
		RX_CDR_LOL_CH_S     => rx_cdr_lol(i),
		RX_LOS_LOW_CH_S     => rx_los_low(i),
		RX_PCS_RST_CH_C     => rx_pcs_rst(i),
		WA_POSITION         => "0000", -- for master
		STATE_OUT           => rx_fsm_state(i) -- ready when x"6"
	);

rx_rst_n <= '0' when (RESET='1') or (CLEAR='1') else '1';

THE_TX_FSM : tx_reset_fsm
	port map(
		RST_N           => tx_rst_n,
		TX_REFCLK       => CLK,
		TX_PLL_LOL_QD_S => tx_pll_lol,
		RST_QD_C        => rst_qd_S(i),
		TX_PCS_RST_CH_C => tx_pcs_rst(i),
		STATE_OUT       => tx_fsm_state(i) -- ready when x"5"
	);
	
process(CLK)
begin
	if (rising_edge(CLK)) then 
		tx_rst_n <= not CLEAR;
	end if;
end process;

end generate;
    

GENERATE_RXDATA_FSM: for i in 0 to 3 generate  

	HUB_8to16_SODA1: HUB_8to16_SODA 
		port map(
			clock => rx_fullclk_i(i),
			reset => RESET,
			data_in => rx_data(i),
			char_is_k => rx_k(i),
			fifo_data => fifo_rx_din(i*18+17 downto i*18),
			fifo_full => fifo_rx_full(i),
			fifo_write => fifo_rx_wr_en(i),
			RX_DLM => RX_DLM_S(i),
			RX_DLM_WORD => RX_DLM_WORD_S(8*i+7 downto 8*i),
			error => open
		);

	THE_FIFO_SFP_TO_FPGA: trb_net_fifo_16bit_bram_dualport
		generic map(
			USE_STATUS_FLAGS => c_NO)
		port map( 
			read_clock_in => SYSCLK,
			write_clock_in => rx_fullclk_i(i),
			read_enable_in => fifo_rx_rd_en(i),
			write_enable_in => fifo_rx_wr_en(i),
			fifo_gsr_in => fifo_rx_reset(i),
			write_data_in => fifo_rx_din(i*18+17 downto i*18),
			read_data_out => fifo_rx_dout(i*18+17 downto i*18),
			full_out => fifo_rx_full(i),
			empty_out => fifo_rx_empty(i)
		);
	fifo_rx_reset(i) <= reset_i or not rx_allow_q(i);
	fifo_rx_rd_en(i) <= not fifo_rx_empty(i);

	buf_med_data_out(i*16+15 downto i*16) <= fifo_rx_dout(i*18+15 downto i*18);
	buf_med_dataready_out(i) <= not fifo_rx_dout(i*18+17) and not fifo_rx_dout(i*18+16) 
								  and not last_fifo_rx_empty(i) and rx_allow_q(i);
	buf_med_packet_num_out(i*3+2 downto i*3) <= rx_counter(i*3+2 downto i*3);

	THE_SYNC_PROC: process(SYSCLK)
	begin
		if rising_edge(SYSCLK)then
			med_dataready_out(i) <= buf_med_dataready_out(i);
			med_data_out(i*16+15 downto i*16) <= buf_med_data_out(i*16+15 downto i*16);
			med_packet_num_out(i*3+2 downto i*3) <= buf_med_packet_num_out(i*3+2 downto i*3);
			if reset_i = '1' then
				med_dataready_out(i) <= '0';
			end if;
		end if;
	end process;
		
	--rx packet counter
	---------------------
	THE_RX_PACKETS_PROC: process(SYSCLK)
	begin
		if (rising_edge(SYSCLK)) then
			last_fifo_rx_empty(i) <= fifo_rx_empty(i);
			if reset_i = '1' or rx_allow_q(i) = '0' then
				rx_counter(i*3+2 downto i*3) <= c_H0;
			else
				if( buf_med_dataready_out(i) = '1' ) then
					if( rx_counter(i*3+2 downto i*3) = c_max_word_number ) then
						rx_counter(i*3+2 downto i*3) <= (others => '0');
					else
						rx_counter(i*3+2 downto i*3) <= rx_counter(i*3+2 downto i*3) + 1;
					end if;
				end if;
			end if;
		end if;
	end process;


	THE_CNT_RESET_PROC : process(rx_fullclk_i(i))
	begin
		if rising_edge(rx_fullclk_i(i)) then
			reset_i_rx(i) <= reset_i;    
			if reset_i_rx(i) = '1' then
				send_reset_words(i)  <= '0';
				make_trbnet_reset(i) <= '0';
				reset_word_cnt(i)    <= (others => '0');
			else
				send_reset_words(i)   <= '0';
				make_trbnet_reset(i)  <= '0';
				if (rx_k(i)='1') and (rx_data(i)=x"FE") then
					if reset_word_cnt(i)(4) = '0' then
						reset_word_cnt(i) <= reset_word_cnt(i) + 1;
					else
						send_reset_words(i) <= '1';
					end if;
				else
					reset_word_cnt(i)    <= (others => '0');
					make_trbnet_reset(i) <= reset_word_cnt(i)(4);
				end if;
			end if;
		end if;
	end process;

	THE_RESET_SYNC: HUB_posedge_to_pulse
		port map(
			clock_in => rx_fullclk_i(i),
			clock_out => SYSCLK,
			en_clk => '1',
			signal_in => make_trbnet_reset(i),
			pulse  => make_trbnet_reset_q(i)
		);
		
	HUB_SODA_clockcrossing1: HUB_SODA_clockcrossing
		port map(
			write_clock => rx_fullclk_i(i),
			read_clock => CLK,
			DLM_in => RX_DLM_S(i),
			DLM_WORD_in => RX_DLM_WORD_S(8*i+7 downto 8*i),
			DLM_out => RX_DLM(i),
			DLM_WORD_out => RX_DLM_WORD(i*8+7 downto i*8),
			error => open
		);
		
end generate; -- end GENERATE_RXDATA_FSM 

GENERATE_TXDATA_FSM: for i in 0 to 3 generate  

	HUB_16to8_SODA1: HUB_16to8_SODA 
		port map(
			clock => CLK,
			reset => send_reset_in(i),
			fifo_data => fifo_tx_dout(i*18+15 downto i*18),
			fifo_empty => fifo_tx_empty(i),
			fifo_read => fifo_tx_rd_en(i),
			TX_DLM => TX_DLM(i),
			TX_DLM_WORD => TX_DLM_WORD(i*8+7 downto i*8),
			data_out => tx_data(i),
			char_is_k => tx_k(i),
			error => open
		);
		
	--TX Fifo & Data output to Serdes
	THE_FIFO_FPGA_TO_SFP: trb_net_fifo_16bit_bram_dualport
		generic map(
			USE_STATUS_FLAGS => c_NO)
		port map( 
			read_clock_in => CLK,
			write_clock_in => SYSCLK,
			read_enable_in => fifo_tx_rd_en(i),
			write_enable_in => fifo_tx_wr_en(i),
			fifo_gsr_in => fifo_tx_reset(i),
			write_data_in => fifo_tx_din(i*18+17 downto i*18),
			read_data_out => fifo_tx_dout(i*18+17 downto i*18),
			full_out => fifo_tx_full(i),
			empty_out => fifo_tx_empty(i),
			almost_full_out => fifo_tx_almost_full(i)
		);

	fifo_tx_reset(i) <= reset_i or not tx_allow_q(i);
	fifo_tx_din(i*18+17 downto i*18) <= med_packet_num_in(i*3+2) & med_packet_num_in(i*3+0) & med_data_in(i*16+15 downto i*16);
	fifo_tx_wr_en(i) <= med_dataready_in(i) and tx_allow_q(i);
	med_read_out(i) <= tx_allow_q(i) and not fifo_tx_almost_full(i);

end generate;  -- end GENERATE_TXDATA_FSM 

   
--------------------------------------------------------------------------
--------------------------------------------------------------------------

-- SerDes clock output to FPGA fabric
refclk2core_out <= '0';

--------------------------------------------------------------------------
--Generate LED signals
--------------------------------------------------------------------------
PROC_LED : process(SYSCLK)
begin
	if rising_edge(SYSCLK) then
		led_counter <= led_counter + 1;

		if led_counter = 0 then
			rx_led <= x"0";
		else
			rx_led <= rx_led or buf_med_dataready_out;
		end if;
		if led_counter = 0 then
			tx_led <= x"0";
		else
			tx_led <= tx_led or not (tx_k(3) & tx_k(2) & tx_k(1) & tx_k(0));
		end if;
	end if;
end process;

gen_outputs : for i in 0 to 3 generate
	stat_op(i*16+15)              <= send_reset_words_q(i);
	stat_op(i*16+14)              <= buf_stat_op(i*16+14);
	stat_op(i*16+13)              <= make_trbnet_reset_q(i);
	stat_op(i*16+12)              <= '0';
	stat_op(i*16+11)              <= tx_led(i); --tx led
	stat_op(i*16+10)              <= rx_led(I); --rx led
	stat_op(i*16+9 downto i*16+0) <= buf_stat_op(i*16+9 downto i*16+0);
												  
	-- Debug output                                 
	stat_debug(i*64+7 downto i*64+0)  <= rx_data(i);            
	stat_debug(i*64+16) <= rx_k(i);               
	stat_debug(i*64+19 downto i*64+18) <= (others => '0');
	stat_debug(i*64+23 downto i*64+20) <= buf_stat_debug(i*16+3 downto i*16+0);
	stat_debug(i*64+24)                <= fifo_rx_rd_en(i);
	stat_debug(i*64+25)                <= fifo_rx_wr_en(i);
	stat_debug(i*64+26)                <= fifo_rx_reset(i);
	stat_debug(i*64+27)                <= fifo_rx_empty(i);
	stat_debug(i*64+28)                <= fifo_rx_full_q(i);
	stat_debug(i*64+29)                <= '0';
	stat_debug(i*64+30)                <= rx_allow_q(i);
	stat_debug(i*64+41 downto i*64+31) <= (others => '0');
	stat_debug(i*64+42)                <= sysclk;
	stat_debug(i*64+43)                <= sysclk;
	stat_debug(i*64+59 downto i*64+44) <= (others => '0');
	stat_debug(i*64+63 downto i*64+60) <= buf_stat_debug(i*16+3 downto i*16+0);
end generate;

end architecture;