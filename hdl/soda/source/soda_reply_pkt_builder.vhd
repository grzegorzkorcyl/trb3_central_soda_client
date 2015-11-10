library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb_net16_hub_func.all; 
use work.soda_components.all;

entity soda_reply_pkt_builder is
	port(
		SODACLK						: in	std_logic; -- fabric clock
		RESET							: in	std_logic; -- synchronous reset
		CLEAR							: in	std_logic; -- asynchronous reset
		CLK_EN						: in	std_logic; 
		--Internal Connection
		LINK_PHASE_IN				: in	std_logic := '0';	--_vector(1 downto 0) := (others => '0');
		START_OF_SUPERBURST		: in	std_logic := '0';
		SUPER_BURST_NR_IN			: in	std_logic_vector(30 downto 0) := (others => '0');
		SODA_CMD_STROBE_IN		: in	std_logic := '0';	-- 
		SODA_CMD_WORD_IN			: in	std_logic_vector(30 downto 0) := (others => '0');		--REGIO_CTRL_REG in trbnet handler is 32 bit
		TX_DLM_PREVIEW_OUT		: out	std_logic := '0';	-- 
		TX_DLM_OUT					: out	std_logic := '0';	-- 
		TX_DLM_WORD_OUT			: out	std_logic_vector(7 downto 0) := (others => '0')
	);
end soda_reply_pkt_builder;

architecture soda_reply_pkt_builder_arch of soda_reply_pkt_builder is

	type		reply_packet_state_type is	(	c_IDLE, c_ERROR,
													c_WAIT4BST1, c_BST1, c_BST2, c_BST3, c_BST4, c_BST5, c_BST6, c_BST7, c_BST8,
													c_WAIT4CMD1, c_CMD1, c_CMD2, c_CMD3, c_CMD4, c_CMD5, c_CMD6, c_CMD7, c_CMD8
												);
	signal	reply_packet_state_S		: reply_packet_state_type := c_IDLE;
	signal	reply_packet_bits_S		: std_logic_vector(7 downto 0)	:= (others => '0');

	signal	soda_dlm_preview_S		: std_logic;
	signal	sequence_error_S			: std_logic;
	signal	next_superburst_nr_S		: std_logic_vector(30 downto 0);


begin
	
--	TX_DLM_PREVIEW_OUT		<= '1' when (((LINK_PHASE_IN='1') and ((soda_dlm_preview_S='1') or (START_OF_SUPERBURST='1') or (SODA_CMD_STROBE_IN='1'))) or
--													((LINK_PHASE_IN='0') and (soda_dlm_preview_S='1'))) 
--													else '0';
	TX_DLM_PREVIEW_OUT		<= soda_dlm_preview_S;

sequence_check_proc : process(SODACLK)
	begin
		if rising_edge(SODACLK) then
			if (RESET='1') then
				sequence_error_S		<= '0';
				next_superburst_nr_S	<= (others => '0');
			else
				case reply_packet_state_S is
					when c_IDLE	=>
						if (START_OF_SUPERBURST='1') then
							if (SUPER_BURST_NR_IN=next_superburst_nr_S) then
								sequence_error_S		<= '0';
							else
								sequence_error_S		<= '1';
							end if;
						end  if;
--					when c_BST1 =>
--						sequence_error_S		<= '0';
--						next_superburst_nr_S	<= SUPER_BURST_NR_IN + 1;
					when c_BST2 =>
						sequence_error_S		<= '0';
						next_superburst_nr_S	<= SUPER_BURST_NR_IN + 1;
					when others =>
				end case;
			end if;
		end if;
	end process;

reply_fsm_proc : process(SODACLK)
	begin
		if rising_edge(SODACLK) then
			if (RESET='1') then
				reply_packet_bits_S	<= x"00";
				reply_packet_state_S	<= c_IDLE;
				soda_dlm_preview_S	<= '0';
				TX_DLM_OUT				<= '0';
				TX_DLM_WORD_OUT		<= (others=>'0');
			else
				case reply_packet_state_S is
					when c_IDLE	=>
						if (START_OF_SUPERBURST='1') then
							soda_dlm_preview_S	<= '1';
							if (LINK_PHASE_IN = c_PHASE_H) then
								reply_packet_bits_S	<= x"11";
								reply_packet_state_S	<= c_BST1;
								TX_DLM_OUT				<= '1';
								TX_DLM_WORD_OUT		<= SUPER_BURST_NR_IN(7 downto 0);
							else
								reply_packet_bits_S	<= x"10";
								reply_packet_state_S	<= c_WAIT4BST1;
								TX_DLM_OUT				<= '0';
							end if;
						elsif (SODA_CMD_STROBE_IN='1') then
							soda_dlm_preview_S		<= '1';
							if (LINK_PHASE_IN = c_PHASE_H) then
								reply_packet_bits_S	<= x"21";
								reply_packet_state_S	<= c_CMD1;
								TX_DLM_OUT				<= '1';
								TX_DLM_WORD_OUT		<= SODA_CMD_WORD_IN(7 downto 0);	--'1' & SODA_CMD_WORD_IN(30 downto 24);
							else
								reply_packet_bits_S	<= x"20";
								reply_packet_state_S	<= c_WAIT4CMD1;
								TX_DLM_OUT				<= '0';
							end if;
						end if;
					when c_WAIT4BST1	=>
						reply_packet_bits_S			<= x"11";
						reply_packet_state_S			<= c_BST1;
						soda_dlm_preview_S			<= '1';
						TX_DLM_OUT						<= '1';
						TX_DLM_WORD_OUT				<= SUPER_BURST_NR_IN(7 downto 0);
					when c_BST1 =>
						reply_packet_bits_S			<= x"12";
						reply_packet_state_S			<= c_BST2;
						TX_DLM_OUT						<= '0';
						soda_dlm_preview_S			<= '0';
					when c_BST2 =>
						reply_packet_bits_S			<= x"00";
						reply_packet_state_S			<= c_IDLE;
					when c_WAIT4CMD1	=>
						reply_packet_bits_S			<= x"21";
						reply_packet_state_S			<= c_CMD1;
						soda_dlm_preview_S			<= '1';
						TX_DLM_OUT						<= '1';
						TX_DLM_WORD_OUT				<= SODA_CMD_WORD_IN(7 downto 0);	--'1' & SODA_CMD_WORD_IN(30 downto 24);
					when c_CMD1 =>
						reply_packet_bits_S			<= x"22";
						reply_packet_state_S			<= c_CMD2;
						TX_DLM_OUT						<= '0';
						soda_dlm_preview_S			<= '0';
					when c_CMD2 =>
						reply_packet_bits_S			<= x"00";
						reply_packet_state_S			<= c_IDLE;
					when others =>
						reply_packet_bits_S			<= x"00";
						reply_packet_state_S			<= c_IDLE;
						TX_DLM_OUT						<= '0';
						soda_dlm_preview_S			<= '0';
				end case;
			end if;
		end if;
	end process;

end soda_reply_pkt_builder_arch;