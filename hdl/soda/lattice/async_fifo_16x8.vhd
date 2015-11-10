library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_ARITH.ALL;
use IEEE.std_logic_UNSIGNED.ALL;

entity async_fifo_16x8 is
port (
		rst                     : in std_logic;
		wr_clk                  : in std_logic;
		rd_clk                  : in std_logic;
		din                     : in std_logic_vector(7 downto 0);
		wr_en                   : in std_logic;
		rd_en                   : in std_logic;
		dout                    : out std_logic_vector(7 downto 0);
		full                    : out std_logic;
		empty                   : out std_logic
	);
end async_fifo_16x8;

architecture Behavioral of async_fifo_16x8 is

component async_fifo_16x8_ecp3 is
    port (
        Data: in  std_logic_vector(7 downto 0); 
        WrClock: in  std_logic; 
        RdClock: in  std_logic; 
        WrEn: in  std_logic; 
        RdEn: in  std_logic; 
        Reset: in  std_logic; 
        RPReset: in  std_logic; 
        Q: out  std_logic_vector(7 downto 0); 
        Empty: out  std_logic; 
        Full: out  std_logic);
end component;

begin

async_fifo_16x8_ecp3_1: async_fifo_16x8_ecp3 port map(
        Data => din,
        WrClock => wr_clk,
        RdClock => rd_clk,
        WrEn => wr_en,
        RdEn => rd_en,
        Reset => rst,
        RPReset => rst,
        Q => dout,
        Empty => empty,
        Full => full);

end Behavioral;

