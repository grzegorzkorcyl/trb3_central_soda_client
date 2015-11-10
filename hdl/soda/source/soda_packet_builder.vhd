library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb_net16_hub_func.all; 
use work.soda_components.all;

entity soda_packet_builder is
	port(
		SODACLK						: in	std_logic; -- fabric clock
		RESET							: in	std_logic; -- synchronous reset
		--Internal Connection
		LINK_PHASE_IN				: in	std_logic := '0';	-- even/odd fase needed to match 16-bit link stuff in trb
		SODA_CYCLE_IN				: in	std_logic := '0';	-- 40MHz cycle for soda transmissions
		SODA_CMD_WINDOW_IN		: in	std_logic := '0';
		SODA_CMD_STROBE_IN		: in	std_logic := '0'; 
		START_OF_SUPERBURST		: in	std_logic := '0';
		SUPER_BURST_NR_IN			: in	std_logic_vector(30 downto 0) := (others => '0');
		SODA_CMD_WORD_IN			: in	std_logic_vector(30 downto 0) := (others => '0');		--REGIO_CTRL_REG in trbnet handler is 32 bit
		EXPECTED_REPLY_OUT		: out	std_logic_vector(7 downto 0) := (others => '0');
		SEND_TIME_CAL_OUT			: out	std_logic := '0';
		TX_DLM_PREVIEW_OUT		: out	std_logic := '0';	-- 
		TX_DLM_OUT					: out	std_logic := '0';	-- 
		TX_DLM_WORD_OUT			: out	std_logic_vector(7 downto 0) := (others => '0')
	);
end soda_packet_builder;

architecture Behavioral of soda_packet_builder is

	signal	soda_cmd_pending_S		: std_logic	:= '0';
	signal	soda_cmd_strobe_S			: std_logic	:= '0';
	signal	soda_cmd_word_S			: std_logic_vector(30 downto 0)	:= (others => '0');		-- from slowcontrol
	signal	soda_pkt_word_S			: std_logic_vector(7 downto 0)	:= (others => '0');
	signal	soda_pkt_valid_S			: std_logic;
	signal	reg1_soda_pkt_valid_S	: std_logic;
--	signal	reg2_soda_pkt_valid_S	: std_logic;
	signal	wait4cycle_S				: std_logic;
	

	signal	soc_S							: std_logic;
	signal	eoc_S							: std_logic;
	signal	crc_data_valid_S			: std_logic;
	signal	crc_datain_S				: std_logic_vector(7 downto 0)	:= (others => '0');
	signal	crc_out_S					: std_logic_vector(7 downto 0)	:= (others => '0');
	signal	crc_valid_S					: std_logic;
	
	type		build_packet_state_type is (	c_IDLE, c_ERROR, 
													c_WAIT4CYCLE_B, c_BST1, c_BST2, c_BST3, c_BST4, c_BST5, c_BST6, c_BST7, c_BST8,
													c_WAIT4CYCLE_C, c_CMD1, c_CMD2, c_CMD3, c_CMD4, c_CMD5, c_CMD6, c_CMD7, c_CMD8
													);	--	c_WAIT4BST1, c_WAIT4CMD1, 
	signal	build_packet_state_S		: build_packet_state_type := c_IDLE;
	signal	build_packet_bits_S		: std_logic_vector(7 downto 0)	:= (others => '0');
	
	type		cmd_window_state_type is (	c_WINDOW_IDLE, c_WAIT4WINDOW, c_START_CMD); 
	signal	cmd_window_state_S		: cmd_window_state_type := c_WINDOW_IDLE;
	

	signal	soda_dlm_preview_S		: std_logic;

	signal	PS_crc_out_S			: std_logic_vector(7 downto 0); -- PS
	
begin

	tx_crc8: soda_d8crc8
		port map(
			CLOCK				=> SODACLK,
			RESET				=> RESET,
			SOC_IN			=> soc_S,
			DATA_IN			=> crc_datain_S,
			DATA_VALID_IN	=> crc_data_valid_S,
			EOC_IN			=> eoc_S,
			CRC_OUT			=> crc_out_S,
			CRC_VALID_OUT	=> crc_valid_S
		);

	soda_cmd_word_S			<= SODA_CMD_WORD_IN;
	
--	TX_DLM_PREVIEW_OUT		<= '1' when (((LINK_PHASE_IN='1') and ((soda_dlm_preview_S='1') or (START_OF_SUPERBURST='1') or (soda_cmd_strobe_S='1'))) or
--													((LINK_PHASE_IN='0') and (soda_dlm_preview_S='1'))) 
--													else '0';
	TX_DLM_PREVIEW_OUT		<= '1' when ((soda_dlm_preview_S='1') or ((wait4cycle_S='1') and (SODA_CYCLE_IN='1')))
											else '0';
	TX_DLM_OUT					<=	reg1_soda_pkt_valid_S;
	TX_DLM_WORD_OUT			<=	soda_pkt_word_S;


--	strobe_delay_proc : process(SODACLK)
--	begin
--		if rising_edge(SODACLK) then
--			if (RESET='1') then
--				soda_cmd_pending_S	<= '0';
--			elsif (SODA_CMD_STROBE_IN='1') then
--				soda_cmd_pending_S	<= '1';
--			elsif (soda_cmd_strobe_S='1') then
--				soda_cmd_pending_S	<= '0';
--			end if;
--		end if;
--	end process;


--	strobe_delivery_proc : process(SODACLK)
--	begin
--		if rising_edge(SODACLK) then
--			if (RESET='1') then
--				soda_cmd_strobe_S	<= '0';
--			elsif ((SODA_CMD_STROBE_IN='1') and (soda_cmd_pending_S='1')) then
--				soda_cmd_strobe_S	<= '1';
--			else
--				soda_cmd_strobe_S	<= '0';
--			end if;
--		end if;
--	end process;

	SODA_CMD_FLOWCTRL : process(SODACLK)
	begin
		if( rising_edge(SODACLK) ) then
			if( RESET = '1' ) then
				cmd_window_state_S	<= c_WINDOW_IDLE;
				soda_cmd_pending_S	<= '0';
				soda_cmd_strobe_S		<= '0';
			else
				case cmd_window_state_S is
					when c_WINDOW_IDLE =>
						if (SODA_CMD_STROBE_IN='1') then
							cmd_window_state_S	<= c_WAIT4WINDOW;
							soda_cmd_pending_S	<= '1';
						end if;
					when c_WAIT4WINDOW =>
						if ((SODA_CMD_WINDOW_IN ='1') and (soda_cmd_pending_S ='1')) then
							cmd_window_state_S	<= c_START_CMD;
							soda_cmd_strobe_S		<= '1';
							soda_cmd_pending_S	<= '0';
						end if;
					when c_START_CMD =>
						cmd_window_state_S	<= c_WINDOW_IDLE;
						soda_cmd_strobe_S		<= '0';
						soda_cmd_pending_S	<= '0';
					when others =>
						cmd_window_state_S	<= c_WINDOW_IDLE;
						soda_cmd_strobe_S		<= '0';
						soda_cmd_pending_S	<= '0';
				end case;
			end if;
		end if;
	end process SODA_CMD_FLOWCTRL;			

	packet_fsm_proc : process(SODACLK)
	begin
		if rising_edge(SODACLK) then
			if (RESET='1') then
				build_packet_bits_S		<= x"00";
				build_packet_state_S		<=	c_IDLE;
				soda_dlm_preview_S		<= '0';
				soda_pkt_valid_S			<= '0';
				reg1_soda_pkt_valid_S	<= '0';
--				reg2_soda_pkt_valid_S	<= '0';
				wait4cycle_S				<= '0';
				soda_pkt_word_S			<= (others => '0');
			else
				soda_pkt_valid_S			<= reg1_soda_pkt_valid_S;
--				reg2_soda_pkt_valid_S	<= reg1_soda_pkt_valid_S;
				case build_packet_state_S is
--					when c_IDLE	=>
--						if (START_OF_SUPERBURST='1') then
--							soda_dlm_preview_S	<= '1';
--							if (LINK_PHASE_IN = c_PHASE_H) then
--								build_packet_state_S		<= c_BST1;
--								soda_pkt_valid_S	<= '1';
--								soda_pkt_word_S	<= '1' & SUPER_BURST_NR_IN(30 downto 24);
--							else
--								build_packet_state_S		<= c_WAIT4BST1;
--								soda_pkt_valid_S	<= '0';
--							end if;
--						elsif (soda_cmd_strobe_S='1') then
--							soda_dlm_preview_S	<= '1';
--							if ((SODA_CYCLE_IN = '1') and (LINK_PHASE_IN = c_PHASE_H)) then
--								build_packet_state_S		<= c_CMD1;
--								soda_pkt_valid_S	<= '1';
--								soda_pkt_word_S	<= '0' & soda_cmd_word_S(30 downto 24);
--							else
--								build_packet_state_S		<= c_WAIT4CMD1;
--								soda_pkt_valid_S	<= '0';
--							end if;
--						else
--							build_packet_state_S	<=	c_IDLE;
--							SEND_TIME_CAL_OUT		<= '0';
--							soda_pkt_valid_S		<= '0';
--							soda_pkt_word_S		<= (others=>'0');
--						end if;
					when c_IDLE	=>
						if (START_OF_SUPERBURST='1') then
							if ((SODA_CYCLE_IN='1') and (LINK_PHASE_IN = c_PHASE_H)) then
								build_packet_bits_S		<= x"11";
								build_packet_state_S		<= c_BST1;
--								soda_dlm_preview_S		<= '1';
								reg1_soda_pkt_valid_S	<= '1';
								soda_pkt_word_S			<= '1' & SUPER_BURST_NR_IN(30 downto 24);
							else
								build_packet_bits_S		<= x"10";
								build_packet_state_S		<= c_WAIT4CYCLE_B;
								reg1_soda_pkt_valid_S	<= '0';
							end if;
						elsif (soda_cmd_strobe_S='1') then
							if ((SODA_CYCLE_IN = '1') and (LINK_PHASE_IN = c_PHASE_H)) then
								build_packet_bits_S		<= x"21";
								build_packet_state_S		<= c_CMD1;
--								soda_dlm_preview_S		<= '1';
								reg1_soda_pkt_valid_S	<= '1';
								soda_pkt_word_S			<= '0' & soda_cmd_word_S(30 downto 24);
							else
								build_packet_bits_S		<= x"20";
								build_packet_state_S		<= c_WAIT4CYCLE_C;
								reg1_soda_pkt_valid_S	<= '0';
							end if;
						else
							build_packet_bits_S			<= x"00";
							build_packet_state_S			<=	c_IDLE;
							SEND_TIME_CAL_OUT				<= '0';
							reg1_soda_pkt_valid_S		<= '0';
							soda_pkt_word_S				<= (others=>'0');
						end if;
					when c_WAIT4CYCLE_B =>
						wait4cycle_S						<= '1';
						if ((SODA_CYCLE_IN='1') and (LINK_PHASE_IN = c_PHASE_H)) then
							build_packet_bits_S			<= x"11";
							build_packet_state_S			<= c_BST1;
							wait4cycle_S					<= '0';
							soda_dlm_preview_S			<= '1';
							reg1_soda_pkt_valid_S		<= '1';
							soda_pkt_word_S				<= '1' & SUPER_BURST_NR_IN(30 downto 24);
						else
							build_packet_bits_S			<= x"10";
							build_packet_state_S			<= c_WAIT4CYCLE_B;
							soda_dlm_preview_S			<= '0';
							reg1_soda_pkt_valid_S		<= '0';
						end if;
--					when c_WAIT4BST1	=>
--						build_packet_state_S						<= c_BST1;
--						soda_dlm_preview_S				<= '1';
--						reg1_soda_pkt_valid_S			<= '1';
--						soda_pkt_word_S					<= '1' & SUPER_BURST_NR_IN(30 downto 24);
					when c_BST1	=>
						build_packet_bits_S				<= x"12";
						build_packet_state_S				<= c_BST2;
						reg1_soda_pkt_valid_S			<= '0';
					when c_BST2	=>
						build_packet_bits_S				<= x"13";
						build_packet_state_S				<= c_BST3;
						reg1_soda_pkt_valid_S			<= '1';
						soda_pkt_word_S					<= SUPER_BURST_NR_IN(23 downto 16);
					when c_BST3	=>
						build_packet_bits_S				<= x"14";
						build_packet_state_S				<= c_BST4;
						reg1_soda_pkt_valid_S			<= '0';
					when c_BST4	=>
						build_packet_bits_S				<= x"15";
						build_packet_state_S				<= c_BST5;
						reg1_soda_pkt_valid_S			<= '1';
						soda_pkt_word_S					<= SUPER_BURST_NR_IN(15 downto 8);
					when c_BST5	=>
						build_packet_bits_S				<= x"16";
						build_packet_state_S				<= c_BST6;
						reg1_soda_pkt_valid_S			<= '0';
					when c_BST6	=>
						build_packet_bits_S				<= x"17";
						build_packet_state_S				<= c_BST7;
						reg1_soda_pkt_valid_S			<= '1';
						soda_pkt_word_S					<= SUPER_BURST_NR_IN(7 downto 0);
						EXPECTED_REPLY_OUT				<= SUPER_BURST_NR_IN(7 downto 0);
					when c_BST7	=>
						build_packet_bits_S				<= x"18";
						build_packet_state_S				<= c_BST8;
						soda_dlm_preview_S				<= '0';
						reg1_soda_pkt_valid_S			<= '0';
					when c_BST8	=>
						if (soda_cmd_strobe_S='0') then
							soda_dlm_preview_S			<= '0';
							build_packet_bits_S			<= x"00";
							build_packet_state_S			<= c_IDLE;
						else
							soda_dlm_preview_S			<= '1';
							build_packet_bits_S			<= x"21";
							build_packet_state_S			<= c_CMD1;
						end if;
						reg1_soda_pkt_valid_S			<= '0';
						soda_pkt_word_S					<= (others=>'0');
					when c_WAIT4CYCLE_C	=>
						wait4cycle_S						<= '1';
						if ((SODA_CYCLE_IN = '1') and (LINK_PHASE_IN = c_PHASE_H)) then
							build_packet_bits_S			<= x"21";
							build_packet_state_S			<= c_CMD1;
							wait4cycle_S					<= '0';
							soda_dlm_preview_S			<= '1';
							reg1_soda_pkt_valid_S		<= '1';
							soda_pkt_word_S				<= '0' & soda_cmd_word_S(30 downto 24);
						else
							build_packet_bits_S			<= x"20";
							build_packet_state_S			<= c_WAIT4CYCLE_C;
							soda_dlm_preview_S			<= '0';
							reg1_soda_pkt_valid_S		<= '0';
							soda_pkt_word_S				<= '0' & soda_cmd_word_S(30 downto 24);
						end if;
--					when c_WAIT4CMD1	=>
--						build_packet_state_S	<= c_CMD1;
--						soda_dlm_preview_S	<= '1';
--						soda_pkt_valid_S		<= '1';
--						soda_pkt_word_S		<= '0' & soda_cmd_word_S(30 downto 24);
					when c_CMD1	=>
						build_packet_bits_S				<= x"22";
						build_packet_state_S				<= c_CMD2;
						soda_dlm_preview_S				<= '1';
						reg1_soda_pkt_valid_S			<= '0';
						SEND_TIME_CAL_OUT					<= soda_cmd_word_S(30);
					when c_CMD2	=>
						build_packet_bits_S				<= x"23";
						build_packet_state_S				<= c_CMD3;
						reg1_soda_pkt_valid_S			<= '1';
						soda_pkt_word_S					<= soda_cmd_word_S(23 downto 16);
						SEND_TIME_CAL_OUT					<= '0';
					when c_CMD3	=>
						build_packet_bits_S				<= x"24";
						build_packet_state_S				<= c_CMD4;
						reg1_soda_pkt_valid_S			<= '0';
					when c_CMD4	=>
						build_packet_bits_S				<= x"25";
						build_packet_state_S				<= c_CMD5;
						reg1_soda_pkt_valid_S			<= '1';
						soda_pkt_word_S					<= soda_cmd_word_S(15 downto 8);
					when c_CMD5	=>
						build_packet_bits_S				<= x"26";
						build_packet_state_S				<= c_CMD6;
						reg1_soda_pkt_valid_S			<= '0';
						if (crc_valid_S = '0') then --PS 
							build_packet_state_S			<= c_ERROR; --PS
						else
							PS_crc_out_S				<= crc_out_S; --PS
						end if;
					when c_CMD6	=>
						build_packet_bits_S				<= x"27";
						build_packet_state_S				<= c_CMD7;
						reg1_soda_pkt_valid_S			<= '1';
						soda_pkt_word_S					<= PS_crc_out_S; --PS: crc needed soda_cmd_word_S(7 downto 0);
						EXPECTED_REPLY_OUT				<= PS_crc_out_S; --PS: crc needed soda_cmd_word_S(7 downto 0);
					when c_CMD7	=>
						if (crc_valid_S = '1') then  --PS
						build_packet_bits_S				<= x"0E";
							build_packet_state_S			<= c_ERROR;
						else
							build_packet_bits_S			<= x"28";
							build_packet_state_S			<= c_CMD8;
						end if;
						soda_dlm_preview_S				<= '0';
						reg1_soda_pkt_valid_S			<= '0';
					when c_CMD8	=>
						build_packet_bits_S				<= x"00";
						build_packet_state_S				<= c_IDLE;
						soda_dlm_preview_S				<= '0';
						reg1_soda_pkt_valid_S			<= '0';
						soda_pkt_word_S					<= (others=>'0');
					when c_ERROR	=>
						build_packet_bits_S				<= x"00";
						build_packet_state_S				<= c_IDLE;
						soda_dlm_preview_S				<= '0';
						reg1_soda_pkt_valid_S			<= '0';
					when others	=>
						build_packet_bits_S				<= x"00";
						build_packet_state_S				<= c_IDLE;
						soda_dlm_preview_S				<= '0';
						reg1_soda_pkt_valid_S			<= '0';
				end case;
			end if;
		end if;
	end process;

--	soda_cmd_reg_proc : process(SODACLK)
--	begin
--		if rising_edge(SODACLK) then
--			if (RESET='1') then
--				soda_cmd_reg_full_S	<= '0';
--				soda_cmd_reg_S			<= (others => '0');
--			elsif (soda_pkt_valid_S = '1') then
--				soda_cmd_reg_full_S	<= '1';
--				soda_cmd_reg_S			<= '0' & soda_cmd_word_S;
--				
--			end if;
--		end if;
--	end process;


-- -- PS : crc one clock earlier
crc_data_valid_S <=
	'1' when (((build_packet_state_S=c_WAIT4CYCLE_C) and ((SODA_CYCLE_IN = '1') and (LINK_PHASE_IN = c_PHASE_H)))
			or ((build_packet_state_S=c_BST8) and (soda_cmd_strobe_S='1'))
			or ((build_packet_state_S=c_IDLE) and (START_OF_SUPERBURST='0') and (soda_cmd_strobe_S='1') and ((SODA_CYCLE_IN = '1') and (LINK_PHASE_IN = c_PHASE_H))))
	else '1' when (build_packet_state_S=c_CMD2)
	else '1' when (build_packet_state_S=c_CMD4)
	else '0';

crc_datain_S <= 
	'0' & soda_cmd_word_S(30 downto 24) 
		when (((build_packet_state_S=c_WAIT4CYCLE_C) and ((SODA_CYCLE_IN = '1') and (LINK_PHASE_IN = c_PHASE_H)))
			or ((build_packet_state_S=c_BST8) and (soda_cmd_strobe_S='1'))
			or ((build_packet_state_S=c_IDLE) and (START_OF_SUPERBURST='0') and (soda_cmd_strobe_S='1') and ((SODA_CYCLE_IN = '1') and (LINK_PHASE_IN = c_PHASE_H))))
	else soda_cmd_word_S(23 downto 16) when (build_packet_state_S=c_CMD2)
	else soda_cmd_word_S(15 downto 8) when (build_packet_state_S=c_CMD4)
	else (others => '0');

soc_S <= 
	'1' 
		when (((build_packet_state_S=c_WAIT4CYCLE_C) and ((SODA_CYCLE_IN = '1') and (LINK_PHASE_IN = c_PHASE_H)))
			or ((build_packet_state_S=c_BST8) and (soda_cmd_strobe_S='1'))
			or ((build_packet_state_S=c_IDLE) and (START_OF_SUPERBURST='0') and (soda_cmd_strobe_S='1') and ((SODA_CYCLE_IN = '1') and (LINK_PHASE_IN = c_PHASE_H))))
	else '0';
								
eoc_S <= '1' when (build_packet_state_S=c_CMD4) else '0';


							
	-- crc_gen_proc : process(SODACLK, build_packet_state_S)
	-- begin
		-- if rising_edge(SODACLK) then
			-- case build_packet_state_S is
					-- when c_IDLE	=>
						-- crc_data_valid_S	<= '0';
						-- crc_datain_S		<= (others=>'0');
						-- soc_S					<= '1';
						-- eoc_S					<= '0';
					-- when c_CMD1	=>
						-- crc_data_valid_S	<= '1';
						-- crc_datain_S		<= '0' & soda_cmd_word_S(30 downto 24);
						-- soc_S					<= '0';
						-- eoc_S					<= '0';
					-- when c_CMD2	=>
						-- crc_data_valid_S	<= '0';
						-- crc_datain_S		<= (others=>'0');
						-- soc_S					<= '0';
						-- eoc_S					<= '0';
					-- when c_CMD3	=>
						-- crc_data_valid_S	<= '1';
						-- crc_datain_S		<= soda_cmd_word_S(23 downto 16);
						-- soc_S					<= '0';
						-- eoc_S					<= '0';
					-- when c_CMD4	=>
						-- crc_data_valid_S	<= '0';
						-- crc_datain_S		<= (others=>'0');
						-- soc_S					<= '0';
						-- eoc_S					<= '0';
					-- when c_CMD5	=>
						-- crc_data_valid_S	<= '1';
						-- crc_datain_S	<= soda_cmd_word_S(15 downto 8);
						-- soc_S					<= '0';
						-- eoc_S					<= '1';
					-- when c_CMD6	=>
						-- crc_data_valid_S	<= '0';
						-- crc_datain_S		<= (others=>'0');
						-- soc_S					<= '0';
						-- eoc_S					<= '0';
					-- when c_CMD7	=>
						-- crc_data_valid_S	<= '0';
						-- crc_datain_S		<= (others=>'0');
						-- soc_S					<= '0';
						-- eoc_S					<= '0';
					-- when c_CMD8	=>
						-- crc_data_valid_S	<= '0';
						-- crc_datain_S		<= (others=>'0');
						-- soc_S					<= '0';
						-- eoc_S					<= '0';
					-- when others	=>
						-- crc_data_valid_S	<= '0';
						-- crc_datain_S		<= (others=>'0');
						-- soc_S					<= '0';
						-- eoc_S					<= '0';
			-- end case;		
		-- end if;
	-- end process;


end architecture;