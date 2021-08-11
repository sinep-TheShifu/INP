-- Autor reseni: SEM DOPLNTE VASE, JMENO, PRIJMENI A LOGIN

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity ledc8x8 is
port ( -- Sem doplnte popis rozhrani obvodu.
	RESET: in std_logic;
	SMCLK: in std_logic;
	ROW: out std_logic_vector(0 to 7);
	LED: out std_logic_vector(7 downto 0)
);
end ledc8x8;

architecture main of ledc8x8 is

    -- Sem doplnte definice vnitrnich signalu.
	signal counter: std_logic_vector(11 downto 0) := (others => '0');	-- pre citac signalu counter enable
	signal zmena_stavu: std_logic_vector(31 downto 0) := (others => '0');	-- pre zmenu stavu
	signal stav: std_logic_vector(1 downto 0) := "00";			-- signal stavu
	signal ce: std_logic := '0';	-- counter enable
	signal rows: std_logic_vector(7 downto 0) := (others => '0');	-- riadky	
	signal leds: std_logic_vector(7 downto 0) := (others => '0');	-- ledky
	
begin

    -- Sem doplnte popis obvodu. Doporuceni: pouzivejte zakladni obvodove prvky
    -- (multiplexory, registry, dekodery,...), jejich funkce popisujte pomoci
    -- procesu VHDL a propojeni techto prvku, tj. komunikaci mezi procesy,
    -- realizujte pomoci vnitrnich signalu deklarovanych vyse.

    -- DODRZUJTE ZASADY PSANI SYNTETIZOVATELNEHO VHDL KODU OBVODOVYCH PRVKU,
    -- JEZ JSOU PROBIRANY ZEJMENA NA UVODNICH CVICENI INP A SHRNUTY NA WEBU:
    -- http://merlin.fit.vutbr.cz/FITkit/docs/navody/synth_templates.html.

    -- Nezapomente take doplnit mapovani signalu rozhrani na piny FPGA
    -- v souboru ledc8x8.ucf.
	
	-- Citac counter enable
	ce_gen: process(SMCLK, RESET)
	begin
		if RESET = '1' then	-- asynchronny reset
			counter <= (others => '0');
		elsif SMCLK'event and SMCLK = '1' then		-- nastupna hrana
			if counter = "0000111000010000" then	-- 7372800/256/8
				ce <= '1';
				counter <= (others => '0');
			else
				ce <= '0';
			end if;
			counter <= counter + 1;
		end if;
	end process ce_gen;

	-- Zmena stavov
	st_gen: process(SMCLK, RESET)
	begin
		if RESET = '1' then	-- asynchronny reset
			zmena_stavu <= (others => '0');
			stav <= "00";
		elsif SMCLK'event and SMCLK = '1' then	-- nastupna hrana
			zmena_stavu <= zmena_stavu + 1;
			if zmena_stavu = 3686400 then	-- pol sekundy
				stav <= stav + 1;
			elsif zmena_stavu = 7372800 then	-- sekunda
				stav <= stav + 1;
			end if;
		end if;
	end process st_gen;

	-- Rotacny citac
	rotate: process(RESET, ce, SMCLK)
	begin
		if RESET = '1' then	-- asynchronny reset					
			rows <= "10000000";
		elsif (SMCLK'event and SMCLK = '1') and (ce = '1') then		-- nastupna hrana
			rows <= rows(0) & rows(7 downto 1);	-- konkatenancia na posunutie					
		end if;
	end process rotate;

	-- Zasvietenie led
	decoder: process(rows, stav)
	begin
		if stav = "00" then	-- svieti
		case rows is		
			when "10000000" => leds <= "11110111";					
			when "01000000" => leds <= "11101011";					
			when "00100000" => leds <= "11000001";					
			when "00010000" => leds <= "00011110";					
			when "00001000" => leds <= "01101111";					
			when "00000100" => leds <= "01101111";					
			when "00000010" => leds <= "01101111";					
			when "00000001" => leds <= "00011111";					
			when others     => leds <= "11111111";
		end case;

		elsif stav = "01" then	-- nesvieti
		case rows is
			when "10000000" => leds <= "11111111";					
			when "01000000" => leds <= "11111111";					
			when "00100000" => leds <= "11111111";					
			when "00010000" => leds <= "11111111";					
			when "00001000" => leds <= "11111111";					
			when "00000100" => leds <= "11111111";					
			when "00000010" => leds <= "11111111";					
			when "00000001" => leds <= "11111111";					
			when others	=> leds <= "11111111";
		end case;

		else	-- svieti
			case rows is
			when "10000000" => leds <= "11110111";
			when "01000000" => leds <= "11101011";
			when "00100000" => leds <= "11000001";
			when "00010000" => leds <= "00011110";
			when "00001000" => leds <= "01101111";
			when "00000100" => leds <= "01101111";
			when "00000010" => leds <= "01101111";
			when "00000001" => leds <= "00011111";
			when others     => leds <= "11111111";
			end case;
		end if;
	end process decoder;


	ROW <= rows;
	LED <= leds;

end main;




-- ISID: 75579
