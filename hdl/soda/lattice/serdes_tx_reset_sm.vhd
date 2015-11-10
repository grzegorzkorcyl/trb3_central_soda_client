--TX Reset Sequence state machine--
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity serdes_tx_reset_sm is
port (
	rst_n 			: in std_logic;
	refclkdiv2      : in std_logic;
	tx_pll_lol_qd_s : in std_logic;
	rst_qd_c		: out std_logic;
	tx_pcs_rst_ch_c : out std_logic_vector(3 downto 0);
	STATE_OUT       : out std_logic_vector(3 downto 0)
	);
end serdes_tx_reset_sm;

architecture serdes_tx_reset_sm_arch of serdes_tx_reset_sm is

type statetype is (QUAD_RESET, WAIT_FOR_TIMER1, CHECK_PLOL, WAIT_FOR_TIMER2, NORMAL);

signal	cs:		statetype;	-- current state of lsm
signal	ns:		statetype;	-- next state of lsm

signal 	tx_pll_lol_qd_s_int	: std_logic;
signal 	tx_pcs_rst_ch_c_int	: std_logic_vector(3 downto 0);
signal 	rst_qd_c_int		: std_logic;
	
signal 	reset_timer1:	std_logic;
signal	reset_timer2:	std_logic;

signal	counter1:		std_logic_vector(2 downto 0);
signal	TIMER1:			std_logic;

signal	counter2:		std_logic_vector(18 downto 0);
signal	TIMER2:			std_logic;

begin

process (refclkdiv2, rst_n) 
begin
	if rst_n = '0' then 
		cs <= QUAD_RESET;
		tx_pll_lol_qd_s_int <= '1';
		tx_pcs_rst_ch_c <= "1111";
		rst_qd_c <= '1';
	else if rising_edge(refclkdiv2) then
		cs <= ns;
		tx_pll_lol_qd_s_int <= tx_pll_lol_qd_s;
		tx_pcs_rst_ch_c <= tx_pcs_rst_ch_c_int;
		rst_qd_c <= rst_qd_c_int;
	end if;
	end if;
end process;


--TIMER1 = 20ns;
--Fastest REFLCK =312 MHZ, or 3 ns. We need 8 REFCLK cycles or 4 REFCLKDIV2 cycles
-- A 2 bit counter ([1:0]) counts 4 cycles, so a 3 bit ([2:0]) counter will do if we set TIMER1 = bit[2]


process (refclkdiv2, reset_timer1) 
begin
	if rising_edge(refclkdiv2) then
		if reset_timer1 = '1' then
			counter1 <= "000";
			TIMER1 <= '0';
		else 				
			if counter1(2) = '1' then
				TIMER1 <= '1';
			else
				TIMER1 <='0';
				counter1 <= counter1 + 1 ;
			end if;
		end if;
	end if;
end process;


--TIMER2 = 1,400,000 UI;
--WORST CASE CYCLES is with smallest multipier factor.
-- This would be with X8 clock multiplier in DIV2 mode
-- IN this casse, 1 UI = 2/8 REFCLK  CYCLES = 1/8 REFCLKDIV2 CYCLES
-- SO 1,400,000 UI =1,400,000/8 = 175,000 REFCLKDIV2 CYCLES
-- An 18 bit counter ([17:0]) counts 262144 cycles, so a 19 bit ([18:0]) counter will do if we set TIMER2 = bit[18]


process(refclkdiv2, reset_timer2) 
begin
	if rising_edge(refclkdiv2) then
		if reset_timer2 = '1' then 
			counter2 <= "0000000000000000000";
			TIMER2 <= '0';
		else 
			if counter2(18) = '1' then
--			if counter2(4) = '1' then		-- for simulation
				TIMER2 <='1';
			else
				TIMER2 <='0';
				counter2 <= counter2 + 1 ;
			end if;
		end if;
	end if;
end process;

process(cs, TIMER1, TIMER2, tx_pll_lol_qd_s_int)
begin

		reset_timer1 <= '0';        
		reset_timer2 <= '0';        

	case cs is     
  	
      when QUAD_RESET	=> 
		tx_pcs_rst_ch_c_int <= "1111";        
		rst_qd_c_int <= '1';        
		reset_timer1 <= '1';        
      	ns <= WAIT_FOR_TIMER1;
                		
      when WAIT_FOR_TIMER1	=> 
		tx_pcs_rst_ch_c_int <= "1111";        
		rst_qd_c_int <= '1';
		if TIMER1 = '1' then 
			ns <= CHECK_PLOL;
		else	
			ns <= WAIT_FOR_TIMER1;
      	end if;

      when CHECK_PLOL	=> 
		tx_pcs_rst_ch_c_int <= "1111";        
		rst_qd_c_int <= '0';        
		reset_timer2 <= '1';        
      	ns <= WAIT_FOR_TIMER2;
      	    		
      when WAIT_FOR_TIMER2	=> 
		tx_pcs_rst_ch_c_int <= "1111";        
		rst_qd_c_int <= '0';
		if TIMER2 = '1' then 
			if tx_pll_lol_qd_s_int = '1' then
				ns <= QUAD_RESET;
			else
				ns <= NORMAL;
			end if;
		else
	   		ns <= WAIT_FOR_TIMER2;					
     	    	end if;
     	
	when NORMAL	=> 
		tx_pcs_rst_ch_c_int <= "0000";        
		rst_qd_c_int <= '0';
		if tx_pll_lol_qd_s_int = '1' then 
			ns <= QUAD_RESET;
		else	
			ns <= NORMAL;
      	end if;

	when others =>
		ns <= 	QUAD_RESET;
	
	end case;

end process;

STATE_OUT <= 
	x"1" when cs=QUAD_RESET else
	x"2" when cs=WAIT_FOR_TIMER1 else
	x"3" when cs=CHECK_PLOL else
	x"4" when cs=WAIT_FOR_TIMER2 else
	x"5" when cs=NORMAL else
	x"f";

	
end serdes_tx_reset_sm_arch;	
