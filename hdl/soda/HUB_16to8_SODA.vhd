----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Peter Schakel
-- Create Date:   09-07-2015
-- Module Name:   HUB_16to8_SODA
-- Description:   16 bits to 8 bits conversion and SODA
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
USE ieee.std_logic_unsigned.all ;
USE ieee.std_logic_arith.all ;

----------------------------------------------------------------------------------
-- HUB_16to8_SODA
-- Read from fifo with 16 bits, convert to 8 bits and add idles and SODA K-character
-- If no data is available Idles (data 50 and k-char BC) are put on the output.
-- SODA signals (DLM) are passed on directly (highest priority).
--
-- Library
--
-- Generics:
-- 
-- Inputs:
--     clock : clock synchronous with SODA
--     reset : reset : k-char FE are sent
--     fifo_data : 16-bits input data from fifo
--     fifo_empty : 16-bits input fifo empty signal
--     TX_DLM : transmit SODA character
--     TX_DLM_WORD : SODA character to be transmitted
-- 
-- Outputs:
--     fifo_read : read signal for 16-bits input data fifo
--     data_out : 16-bits output data
--     char_is_k : corresponding byte in 16-bits output data is K-character
--     error : error in DLM or read fifo
-- 
-- Components:
--
----------------------------------------------------------------------------------


entity HUB_16to8_SODA is
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
end HUB_16to8_SODA;

architecture Behavioral of HUB_16to8_SODA is

signal reset_S                  : std_logic;
signal fifo_read_S              : std_logic;
signal fifo_databuf_S           : std_logic_vector(15 downto 0);
signal data_out_S               : std_logic_vector(7 downto 0);
signal char_is_k_S              : std_logic;

signal fifo_buffilled_S         : std_logic := '0';
signal fifo_read_after1clk_S    : std_logic := '0';
signal TX_DLM_S                 : std_logic;

signal second_reset_S           : std_logic;
signal second_idle_S            : std_logic;
signal second_data_S            : std_logic;
signal error_S                  : std_logic;


begin

process (clock)
begin
	if rising_edge(clock) then
		data_out <= data_out_S;
		char_is_k <= char_is_k_S;
		error <= error_S;
	end if;
end process;
fifo_read <= fifo_read_S;

fifo_read_S <= '1' when (fifo_empty='0') 
		and (TX_DLM='0')
		and (fifo_read_after1clk_S='0')
		and ((fifo_buffilled_S='0') or (second_data_S='1'))
		and (not ((fifo_buffilled_S='1') and (TX_DLM_S='1')))
		and (reset_S='0')
	else '0';
	
process (clock)
begin
	if rising_edge(clock) then
		fifo_read_after1clk_S <= fifo_read_S;
		if fifo_read_after1clk_S='1' then
			fifo_databuf_S <= fifo_data;
		end if;
		TX_DLM_S <= TX_DLM;
		reset_S <= reset;
	end if;
end process;

process (clock)
begin
	if rising_edge(clock) then
		error_S <= '0';
		if (TX_DLM_S='1') then
			data_out_S <= TX_DLM_WORD;
			char_is_k_S <= '0';
			if fifo_read_after1clk_S='1' then
				fifo_buffilled_S <= '1';
			end if;
			if TX_DLM='1' then
				error_S <= '1';
			end if;
		elsif (TX_DLM='1') then
			data_out_S <= x"DC";
			char_is_k_S <= '1';
			if fifo_read_after1clk_S='1' then
				fifo_buffilled_S <= '1';
			end if;
		elsif (second_reset_S='1') then
			data_out_S <= x"FE";
			char_is_k_S <= '1';
			second_reset_S <= '0';
		elsif (second_idle_S='1') then
			data_out_S <= x"50";
			char_is_k_S <= '0';
			second_idle_S <= '0';
			if fifo_read_after1clk_S='1' then
				fifo_buffilled_S <= '1';
			end if;
		elsif (second_data_S='1') then
			data_out_S <= fifo_databuf_S(15 downto 8);
			char_is_k_S <= '0';
			second_data_S <= '0';
			if fifo_read_after1clk_S='1' then
				fifo_buffilled_S <= '1';
			else
				fifo_buffilled_S <= '0';
			end if;
		elsif reset_S = '1' then
			data_out_S <= x"FE";
			char_is_k_S <= '1';
			second_reset_S <= '1';
			fifo_buffilled_S <= '0';
			second_idle_S <= '0';
			second_data_S <= '0';
		elsif (fifo_buffilled_S='1') then
			data_out_S <= fifo_databuf_S(7 downto 0);
			char_is_k_S <= '0';
			second_data_S <= '1';
			if fifo_read_after1clk_S='1' then
				error_S <= '1';
			end if;
		elsif (fifo_read_after1clk_S='1') then
			data_out_S <= fifo_data(7 downto 0);
			char_is_k_S <= '0';
			second_data_S <= '1';
			fifo_buffilled_S <= '1';
		else
			data_out_S <= x"BC";
			char_is_k_S <= '1';
			second_idle_S <= '1';
			if fifo_read_after1clk_S='1' then
				fifo_buffilled_S <= '1';
			end if;
		end if;
	end if;
end process;



end Behavioral;


