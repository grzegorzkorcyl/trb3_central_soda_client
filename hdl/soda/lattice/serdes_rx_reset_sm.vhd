--Reset Sequence Generator
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity serdes_rx_reset_sm is
port (
	rst_n			: in std_logic;
	refclkdiv2        : in std_logic;
	tx_pll_lol_qd_s	: in std_logic;
	rx_serdes_rst_ch_c: out std_logic;
	rx_cdr_lol_ch_s	: in std_logic;
	rx_los_low_ch_s	: in std_logic;
	rx_pcs_rst_ch_c	: out std_logic;
    STATE_OUT         : out std_logic_vector(3 downto 0)
);
end serdes_rx_reset_sm ;

architecture serdes_rx_reset_sm_arch of serdes_rx_reset_sm is

type statetype is (WAIT_FOR_PLOL, RX_SERDES_RESET, WAIT_FOR_TIMER1, CHECK_LOL_LOS, WAIT_FOR_TIMER2, NORMAL);

signal	cs:		statetype; 	-- current state of lsm
signal	ns:		statetype;	-- next state of lsm

signal	tx_pll_lol_qd_s_int:	std_logic;
signal	rx_los_low_int:			std_logic;
signal	plol_los_int:			std_logic;
signal	rx_lol_los	:	std_logic;
signal	rx_lol_los_int:		std_logic;
signal	rx_lol_los_del:		std_logic;
signal	rx_pcs_rst_ch_c_int:	std_logic;      
signal	rx_serdes_rst_ch_c_int:	std_logic;

signal	reset_timer1:	std_logic;
signal	reset_timer2:	std_logic;

signal	counter1:	std_logic_vector(1 downto 0);
signal	TIMER1:	std_logic;

signal	counter2: std_logic_vector(18 downto 0);
signal	TIMER2	: std_logic;

begin

rx_lol_los <= rx_cdr_lol_ch_s or rx_los_low_ch_s ;

process(refclkdiv2,rst_n) 
begin
	if rising_edge(refclkdiv2) then
		if rst_n = '0' then 
			cs <= WAIT_FOR_PLOL;
			rx_lol_los_int <= '1';
			rx_lol_los_del <= '1';
			tx_pll_lol_qd_s_int <= '1';
			rx_pcs_rst_ch_c <= '1';
			rx_serdes_rst_ch_c <= '0';
			rx_los_low_int <= '1';
		else 
			cs <= ns;
			rx_lol_los_del <= rx_lol_los;
			rx_lol_los_int <= rx_lol_los_del;
			tx_pll_lol_qd_s_int <= tx_pll_lol_qd_s;
			rx_pcs_rst_ch_c <= rx_pcs_rst_ch_c_int;
			rx_serdes_rst_ch_c <= rx_serdes_rst_ch_c_int;
			rx_los_low_int <= rx_los_low_ch_s;
		end if;
	end if;
end process;

--TIMER1 = 3NS;
--Fastest REFCLK = 312 MHz, or 3ns. We need 1 REFCLK cycles or 2 REFCLKDIV2 cycles
--A 1 bit counter  counts 2 cycles, so a 2 bit ([1:0]) counter will do if we set TIMER1 = bit[1]

process(refclkdiv2, reset_timer1) 
begin 
	if rising_edge(refclkdiv2) then
		if reset_timer1 = '1' then 
			counter1 <= "00";
			TIMER1 <= '0';
		else 
			if counter1(1) = '1' then
				TIMER1 <='1';
			else
				TIMER1 <='0';
				counter1 <= counter1 + 1 ;
			end if;
		end if;
	end if;
end process;

--TIMER2 = 400,000 Refclk cycles or 200,000 REFCLKDIV2 cycles
--An 18 bit counter ([17:0]) counts 262144 cycles, so a 19 bit ([18:0]) counter will do if we set TIMER2 = bit[18]

process(refclkdiv2, reset_timer2) 
begin
	if rising_edge(refclkdiv2) then
		if reset_timer2 = '1' then 
			counter2 <= "0000000000000000000";
			TIMER2 <= '0';
		else 
			if counter2(18) = '1' then
--			if counter2(4) = '1' then -- for simulation
				TIMER2 <='1';
			else
				TIMER2 <='0';
				counter2 <= counter2 + 1 ;
			end if;
		end if;
	end if;
end process;


process(cs, tx_pll_lol_qd_s_int, rx_los_low_int, TIMER1, rx_lol_los_int, TIMER2)
begin
		reset_timer1 <= '0';        
		reset_timer2 <= '0';        

	case cs is
		when WAIT_FOR_PLOL => 
			rx_pcs_rst_ch_c_int <= '1';        
			rx_serdes_rst_ch_c_int <= '0';
			if (tx_pll_lol_qd_s_int = '1' or rx_los_low_int = '1') then  --Also make sure A Signal       
				ns <= WAIT_FOR_PLOL;    			--is Present prior to moving to the next 
			else	
				ns <= RX_SERDES_RESET;
      		end if;
          		
	    when RX_SERDES_RESET => 
			rx_pcs_rst_ch_c_int <= '1';        
			rx_serdes_rst_ch_c_int <= '1';        
			reset_timer1 <= '1';        
      		ns <= WAIT_FOR_TIMER1;

		when WAIT_FOR_TIMER1 => 
			rx_pcs_rst_ch_c_int <= '1';        
			rx_serdes_rst_ch_c_int <= '1';
			if TIMER1 = '1' then 
				ns <= CHECK_LOL_LOS;
			else	
				ns <= WAIT_FOR_TIMER1;
      		end if;
      
		when CHECK_LOL_LOS =>
			rx_pcs_rst_ch_c_int <= '1';        
			rx_serdes_rst_ch_c_int <= '0';        
			reset_timer2 <= '1';        
      		ns <= WAIT_FOR_TIMER2;
        		
		when WAIT_FOR_TIMER2 =>
			rx_pcs_rst_ch_c_int <= '1';        
			rx_serdes_rst_ch_c_int <= '0';
			if rx_lol_los_int = rx_lol_los_del then 	--NO RISING OR FALLING EDGES
				if TIMER2 = '1' then
					if rx_lol_los_int = '1' then 
						ns <= WAIT_FOR_PLOL;
					else
						ns <= NORMAL;
					end if;
				else
					ns <= WAIT_FOR_TIMER2;
				end if;
			else
	   			ns <= CHECK_LOL_LOS; 	--RESET TIMER2					
			end if;

		when NORMAL =>  
			rx_pcs_rst_ch_c_int <= '0';        
			rx_serdes_rst_ch_c_int <= '0';
			if rx_lol_los_int = '1' then
				ns <= WAIT_FOR_PLOL;
			else	
				ns <= NORMAL;
			end if;

		when others =>
			ns <= WAIT_FOR_PLOL;

		end case;

end process;



STATE_OUT <= 
	x"1" when cs=WAIT_FOR_PLOL else
	x"2" when cs=RX_SERDES_RESET else
	x"3" when cs=WAIT_FOR_timer1 else
	x"4" when cs=CHECK_LOL_LOS else
	x"5" when cs=WAIT_FOR_timer2 else
	x"6" when cs=NORMAL else
	x"f";
			
end serdes_rx_reset_sm_arch;
