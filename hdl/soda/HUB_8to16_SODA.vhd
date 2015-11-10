----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Peter Schakel
-- Create Date:   09-07-2015
-- Module Name:   HUB_8to16_SODA
-- Description:   16 bits to 8 bits conversion and SODA
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
USE ieee.std_logic_unsigned.all ;
USE ieee.std_logic_arith.all ;

----------------------------------------------------------------------------------
-- HUB_8to16_SODA
-- Convert 8-bits data from fiber and convert to 16 bits plus two K-character
-- SODA signals (DLM) are passed on directly (highest priority).
--
-- Library
--
-- Generics:
-- 
-- Inputs:
--     clock : clock synchronous with SODA
--     reset : reset : k-char FE are sent
--     data_in : 8-bits input data from fiber
--     char_is_k : data from fiber is k-character
--     fifo_full : full signal from connected fifo: should not 
-- 
-- Outputs:
--     fifo_data : 16-bits output data plus 2 bits for k-character indication 
--     fifo_write : write signal for connected fifo
--     RX_DLM : receive SODA character
--     RX_DLM_WORD : received SODA character
--     error : error in DLM or read fifo
-- 
-- Components:
--
----------------------------------------------------------------------------------


entity HUB_8to16_SODA is
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
end HUB_8to16_SODA;

architecture Behavioral of HUB_8to16_SODA is

signal data_in_S                : std_logic_vector(7 downto 0);
signal char_is_k_S              : std_logic;

signal fifo_write_S             : std_logic;
signal fifo_data_S              : std_logic_vector(17 downto 0);
signal data_buf_S               : std_logic_vector(7 downto 0);
signal char_is_k_buf_S          : std_logic;

signal RX_DLM_WORD_S            : std_logic_vector(7 downto 0);
signal RX_DLM_S                 : std_logic;

signal expect_dlm_word_S        : std_logic := '0';
signal expect_second_idle_S     : std_logic;
signal expect_second_data_S     : std_logic;
signal error_S                  : std_logic;


begin

RX_DLM_WORD <= RX_DLM_WORD_S;
RX_DLM  <= RX_DLM_S;

process (clock)
begin
	if rising_edge(clock) then
		data_in_S <= data_in;
		char_is_k_S <= char_is_k;
		fifo_data <= fifo_data_S;
		fifo_write <= fifo_write_S;
		error <= error_S;
	end if;
end process;

process (clock)
begin
	if rising_edge(clock) then
		error_S <= '0';
		RX_DLM_S <= '0';
		fifo_write_S <= '0';
		if expect_dlm_word_S='1' then
			expect_dlm_word_S <= '0';
			if (char_is_k_S='0') then
				RX_DLM_WORD_S <= data_in_S;
				RX_DLM_S <= '1';
			else
				error_S <= '1';
			end if;
		elsif (char_is_k_S='1') and (data_in_S=x"DC") then
			expect_dlm_word_S <= '1';
		elsif expect_second_idle_S='1' then
			expect_second_idle_S <= '0';
			expect_second_data_S <= '0';
			if (char_is_k_S='1') or (data_in_S/=x"50") then
				error_S <= '1';
			else
--//				fifo_data_S <= "01" & x"50BC";
--//				fifo_write_S <= '1';
--//				if fifo_full='1' then
--//					error_S <= '1';
--//				end if;
			end if;
		elsif (char_is_k_S='1') and (data_in_S=x"BC") then
			expect_second_idle_S <= '1';
		elsif expect_second_data_S='1' then
			expect_second_data_S <= '0';
			fifo_data_S <= char_is_k_S & char_is_k_buf_S & data_in_S & data_buf_S;
			fifo_write_S <= '1';
			if fifo_full='1' then
				error_S <= '1';
			end if;
		else 
			expect_second_data_S <= '1';
			data_buf_S <= data_in_S;
			char_is_k_buf_S <= char_is_k_S;
		end if;
	end if;
end process;



end Behavioral;


