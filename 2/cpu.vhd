-- cpu.vhd: Simple 8-bit CPU (BrainF*ck interpreter)
-- Copyright (C) 2019 Brno University of Technology,
--                    Faculty of Information Technology
-- Author(s): Daniel Andraško <xandra05>
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

-- ----------------------------------------------------------------------------
--                        Entity declaration
-- ----------------------------------------------------------------------------
entity cpu is
 port (
   CLK   : in std_logic;  -- hodinovy signal
   RESET : in std_logic;  -- asynchronni reset procesoru
   EN    : in std_logic;  -- povoleni cinnosti procesoru
 
   -- synchronni pamet RAM
   DATA_ADDR  : out std_logic_vector(12 downto 0); -- adresa do pameti
   DATA_WDATA : out std_logic_vector(7 downto 0); -- mem[DATA_ADDR] <- DATA_WDATA pokud DATA_EN='1'
   DATA_RDATA : in std_logic_vector(7 downto 0);  -- DATA_RDATA <- ram[DATA_ADDR] pokud DATA_EN='1'
   DATA_RDWR  : out std_logic;                    -- cteni (0) / zapis (1)
   DATA_EN    : out std_logic;                    -- povoleni cinnosti
   
   -- vstupni port
   IN_DATA   : in std_logic_vector(7 downto 0);   -- IN_DATA <- stav klavesnice pokud IN_VLD='1' a IN_REQ='1'
   IN_VLD    : in std_logic;                      -- data platna
   IN_REQ    : out std_logic;                     -- pozadavek na vstup data
   
   -- vystupni port
   OUT_DATA : out  std_logic_vector(7 downto 0);  -- zapisovana data
   OUT_BUSY : in std_logic;                       -- LCD je zaneprazdnen (1), nelze zapisovat
   OUT_WE   : out std_logic                       -- LCD <- OUT_DATA pokud OUT_WE='1' a OUT_BUSY='0'
 );
end cpu;


-- ----------------------------------------------------------------------------
--                      Architecture declaration
-- ----------------------------------------------------------------------------
architecture behavioral of cpu is

signal cnt_reg : std_logic_vector(7 downto 0) := "00000000";
signal cnt_inc : std_logic;
signal cnt_dec : std_logic;

signal pc_reg : std_logic_vector(12 downto 0) := "0000000000000";
signal pc_inc : std_logic;
signal pc_dec : std_logic;

signal ptr_reg : std_logic_vector(12 downto 0) := "1000000000000";
signal ptr_inc : std_logic;
signal ptr_dec : std_logic;

signal mx1_sel : std_logic;

signal mx2_sel : std_logic;
signal mx2_out : std_logic_vector (12 downto 0) := "1000000000000";

signal mx3_sel : std_logic_vector (2 downto 0) := "100";

type fsm_state is (
s_init,
s_fetch,
s_decode,		-- dekodovanie
s_ptr_inc,		-- > inkrementacia hodnoty ukazatela
s_ptr_dec, 		-- < dekrementacia hodnoty ukazatela
s_val_inc, s_val_inc1,		-- + inkrementacia hodnoty aktualnej bunky
s_val_dec, s_val_dec1,		-- - dekrementacia hodnoty aktualnej bunky
s_while_start, s_while_start1, s_while_start2, s_while_start3,s_while_start4,		-- [ zaciatok while cyklu
s_while_end, s_while_end1, s_while_end2, s_while_end3, s_while_end4,		-- ] koniec while cyklu
s_print, s_print1,		-- . tlacenie aktualnej bunky
s_save, s_save1,		-- , ulozenie hodnoty aktualnej bunky
s_val_to_tmp, s_val_to_tmp1,		-- $ uloz hodnotu bunky do pomocnej premennej
s_tmp_to_val, s_tmp_to_val1,		-- ! uloz hodnotu pomocnej premennej do bunky
s_null,		-- null zastav vykonavanie programu
s_others
);

signal state_current : fsm_state := s_init;
signal state_next : fsm_state := s_init;

begin
-- CNT PROCESS
cnt_proc : process (CLK, RESET)
begin
	if RESET='1' then
		cnt_reg <= (others => '0');
	elsif CLK'event and CLK = '1' then
		if cnt_inc = '1' then
			cnt_reg <= cnt_reg + 1;
		elsif cnt_dec = '1' then
			cnt_reg <= cnt_reg - 1;
		end if;
	end if;
end process;

-- PC PROCESS
pc_proc : process (CLK, RESET)
begin
	if RESET = '1' then
		pc_reg <= (others => '0');
	elsif CLK'event and CLK = '1' then
		if pc_inc = '1' then
			if pc_reg = "0111111111111" then
				pc_reg <= "0000000000000";
			else
				pc_reg <= pc_reg + 1;
			end if;
		end if;
		if pc_dec = '1' then
			if pc_reg = "0000000000000" then
				pc_reg <= "0111111111111";
			else
				pc_reg <= pc_reg - 1;
			end if;
		end if;
	end if;
end process;

-- PTR PROCESS
ptr_proc : process (CLK, RESET)
begin
	if RESET = '1' then
		ptr_reg <= "1000000000000";
	elsif CLK'event and CLK = '1' then
		if ptr_inc = '1' then
			if ptr_reg = "1111111111111" then
				ptr_reg <= "1000000000000";
			else
				ptr_reg <= ptr_reg + 1;
			end if;
		end if;
		if ptr_dec = '1' then
			if ptr_reg = "1000000000000" then
				ptr_reg <= "1111111111111";
			else
				ptr_reg <= ptr_reg - 1;
			end if;
		end if;
	end if;
end process;

-- MX1
mx1_proc : process (CLK, mx1_sel, pc_reg, mx2_out)
begin
	case mx1_sel is
		when '0' =>
			DATA_ADDR <= pc_reg;
		when others =>
			DATA_ADDR <= mx2_out;
	end case;
end process;

-- MX2
mx2_proc: process (CLK, mx2_sel, ptr_reg, mx2_out)
begin
	case mx2_sel is
		when '0' =>
			mx2_out <= ptr_reg;
		when others =>
			mx2_out <= "1000000000000";
	end case;
end process;

-- MX3
mx3_proc : process (CLK, mx3_sel, DATA_RDATA, IN_DATA)
begin
	case mx3_sel is
		when "000" => DATA_WDATA <= IN_DATA;
		when "001" => DATA_WDATA <= DATA_RDATA - 1;
		when "010" => DATA_WDATA <= DATA_RDATA + 1;
		when "011" => DATA_WDATA <= DATA_RDATA;
		when others => DATA_WDATA <= X"00";
	end case;
end process;

-- CURRENT STATE
state_current_proc : process (CLK, RESET)
begin
	if RESET = '1' then
		state_current <= s_init;
	elsif CLK'event and CLK = '1' then
		if EN = '1' then
			state_current <= state_next;
		end if;
	end if;
end process;

state_next_proc : process (mx1_sel, mx2_sel, mx3_sel, state_current, cnt_reg, IN_VLD, IN_DATA, DATA_RDATA, OUT_BUSY)
begin
	-- INICIALIZATION
	mx3_sel <= "100";
	DATA_EN <= '0';
	DATA_RDWR <= '0';
	IN_REQ <= '0';
	OUT_WE <= '0';
	cnt_inc <= '0';
	cnt_dec <= '0';
	pc_inc <= '0';
	pc_dec <= '0';
	ptr_inc <= '0';
	ptr_dec <= '0';
	
	case state_current is
		when s_init =>
			state_next <= s_fetch;
		
		when s_fetch =>
			DATA_EN <= '1';
			mx1_sel <= '0';
			state_next <= s_decode;
			
		-- DECODING
		when s_decode =>
			case DATA_RDATA is
				when X"3E" => state_next <= s_ptr_inc;
				when X"3C" => state_next <= s_ptr_dec;
				when X"2B" => state_next <= s_val_inc;
				when X"2D" => state_next <= s_val_dec;
				when X"5B" => state_next <= s_while_start;
				when X"5D" => state_next <= s_while_end;
				when X"2E" => state_next <= s_print;
				when X"2C" => state_next <= s_save;
				when X"24" => state_next <= s_val_to_tmp;
				when X"21" => state_next <= s_tmp_to_val;
				when X"00" => state_next <= s_null;
				when others => state_next <= s_others;
			end case;
		
		-- > INKREMENTACIA HODNOTY UKAZATELA
		when s_ptr_inc =>
			ptr_inc <= '1';
			pc_inc <= '1';
			state_next <= s_fetch;
		
		-- < DEKREMENTACIA HODNOTY UKAZATELA
		when s_ptr_dec =>
			ptr_dec <= '1';
			pc_inc <= '1';
			state_next <= s_fetch;
		
		-- + INKREMENTACIA HODNOTY BUNKY
		-- nacitanie aktualnej bunky
		when s_val_inc =>
			DATA_EN <= '1';
			DATA_RDWR <= '0';
			mx1_sel <= '1';
			state_next <= s_val_inc1;
		
		-- prepis hodnoty
		when s_val_inc1 =>
			DATA_EN <= '1';
			DATA_RDWR <= '1';
			mx1_sel <= '1';
			mx3_sel <= "010";
			pc_inc <= '1';
			state_next <= s_fetch;
			
		-- - DEKREMENTACIA HODNOTY BUNKY
		-- nacitanie aktualnej bunky
		when s_val_dec =>
			DATA_EN <= '1';
			DATA_RDWR <= '0';
			mx1_sel <= '1';
			state_next <= s_val_dec1;
			
		-- prepis hodnoty
		when s_val_dec1 =>
			DATA_EN <= '1';
			DATA_RDWR <= '1';
			mx1_sel <= '1';
			mx3_sel <= "001";
			pc_inc <= '1';
			state_next <= s_fetch;
			
		-- [ ZACIATOK CYKLU
		when s_while_start =>
			DATA_EN <= '1';
			DATA_RDWR <= '0';
			mx1_sel <= '1';
			mx2_sel <= '0';
			pc_inc <= '1';
			state_next <= s_while_start1;
		
		when s_while_start1 =>
			state_next <= s_fetch;
			if DATA_RDATA = "00000000" then
				cnt_inc <= '1';
				state_next <= s_while_start2;
			end if;
		
		when s_while_start2 =>
			DATA_EN <= '1';
			DATA_RDWR <= '0';
			mx1_sel <= '0';
			mx2_sel <= '0';
			state_next <= s_while_start3;
			
		when s_while_start3 =>
			if DATA_RDATA = X"5B" then
				cnt_inc <= '1';
			elsif DATA_RDATA = X"5D" then
				cnt_dec <= '1';
			end if;
			pc_inc <= '1';
			state_next<= s_while_start4;
			
		when s_while_start4 =>
			state_next <= s_while_start2;
			if cnt_reg = "00000000" then
				state_next <= s_fetch;
			end if;			
		
		-- ] KONIEC WHILE CYKLU
		when s_while_end =>
			DATA_EN <= '1';
			DATA_RDWR <= '0';
			mx1_sel <= '1';
			mx2_sel <= '0';
			state_next <= s_while_end1;
			
		when s_while_end1 =>
			state_next <= s_fetch;
			if DATA_RDATA /= "00000000" then
				pc_dec <= '1';
				cnt_inc <= '1';
				state_next <= s_while_end2;
			else
				pc_inc <= '1';
			end if;
			
		when s_while_end2 =>
			DATA_EN <= '1';
			DATA_RDWR <= '0';
			mx1_sel <= '0';
			mx2_sel <= '0';
			state_next <= s_while_end3;
			
		when s_while_end3 =>
				if DATA_RDATA = X"5D" then
					cnt_inc <= '1';
				elsif DATA_RDATA = X"5B" then
					cnt_dec <= '1';
				end if;
			state_next <= s_while_end4;
			
		when s_while_end4 =>
			state_next <= s_fetch;
			if cnt_reg = "00000000" then
				pc_inc <= '1';
			else
				pc_dec <= '1';
				state_next <= s_while_end2;
			end if;			
		
		-- . TLAC BUNKY
		-- nacitanie aktualnej bunky
		when s_print =>
			DATA_EN <= '1';
			DATA_RDWR <= '0';
			mx1_sel <= '1';
			state_next <= s_print1;
		
		-- tlac hodnoty
		when s_print1 =>
			if OUT_BUSY = '0' then
				OUT_WE <= '1';
				OUT_DATA <= DATA_RDATA;
				pc_inc <= '1';
				state_next <= s_fetch;
			else
				state_next <= s_print1;
			end if;
		
		-- , ULOZENIE HODNOTY BUNKY 
		when s_save =>
			IN_REQ <= '1';
			state_next <= s_save1;
			
		when s_save1 =>
			if IN_VLD = '1' then
				DATA_EN <= '1';
				DATA_RDWR <= '1';
				mx1_sel <= '1';
				mx3_sel <= "000";
				pc_inc <= '1';
				state_next <= s_fetch;
			else
				IN_REQ <= '1';
				state_next <= s_save1;
			end if;
			
		-- $ ULOZ HODNOTU BUNKY DO TMP
		-- nacitanie hodnoty bunky
		when s_val_to_tmp =>
			DATA_EN <= '1';
			mx1_sel <= '1';
			mx2_sel <= '0';
			state_next <= s_val_to_tmp1;
		
		-- ulozenie do pomocnej premennej
		when s_val_to_tmp1 =>
			DATA_EN <= '1';
			DATA_RDWR <= '1';
			mx1_sel <= '1';
			mx2_sel <= '1';
			mx3_sel <= "011";
			pc_inc <= '1';
			state_next <= s_fetch;
			
		-- ! ULOZ HODNOTU TMP DO BUNKY
		-- nacitanie hodnoty premennej
		when s_tmp_to_val =>
			DATA_EN <= '1';
			DATA_RDWR <= '0';
			mx1_sel <= '1';
			mx2_sel <= '1';
			state_next <= s_tmp_to_val1;
			
		-- ulozenie do bunky
		when s_tmp_to_val1 =>
			DATA_EN <= '1';
			DATA_RDWR <= '1';
			mx1_sel <= '1';
			mx2_sel <= '0';
			mx3_sel <= "011";
			pc_inc <= '1';
			state_next <= s_fetch;
		
		-- null ZASTAV VYKONAVANIE PROGRAMU
		when s_null =>
			state_next <= s_null;
			
		when s_others =>
			pc_inc <= '1';
			state_next <= s_fetch;	
		
		when others =>		
	end case;
end process;
end behavioral;
 
