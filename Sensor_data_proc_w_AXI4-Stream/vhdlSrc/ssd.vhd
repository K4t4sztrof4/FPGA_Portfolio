library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity seven_segment_display is
    Port ( digit0 : in STD_LOGIC_VECTOR (4 downto 0);
           digit1 : in STD_LOGIC_VECTOR (4 downto 0);
           digit2 : in STD_LOGIC_VECTOR (4 downto 0);
           digit3 : in STD_LOGIC_VECTOR (4 downto 0);
           clk : in STD_LOGIC;
           cat : out STD_LOGIC_VECTOR (6 downto 0);
           an : out STD_LOGIC_VECTOR (3 downto 0));
end seven_segment_display;

architecture Behavioral of seven_segment_display is

signal cnt : STD_LOGIC_VECTOR (15 downto 0) := (others => '0');
signal digit_to_display : STD_LOGIC_VECTOR (4 downto 0) := (others => '0');

constant CH_BLANK       : std_logic_vector(4 downto 0) := "11000"; -- example
constant CH_UNDERSCORE  : std_logic_vector(4 downto 0) := "10010"; -- example
constant CH_A           : std_logic_vector(4 downto 0) := "01010";
constant CH_U           : std_logic_vector(4 downto 0) := "10100";
constant CH_H           : std_logic_vector(4 downto 0) := "10000";
constant CH_R           : std_logic_vector(4 downto 0) := "10001";
constant CH_E           : std_logic_vector(4 downto 0) := "01110";
constant CH_S           : std_logic_vector(4 downto 0) := "00101";
constant CH_T           : std_logic_vector(4 downto 0) := "10101";
constant CH_I           : std_logic_vector(4 downto 0) := "10011";
constant CH_P           : std_logic_vector(4 downto 0) := "10011";
constant CH_o           : std_logic_vector(4 downto 0) := "10011";
constant CH_c           : std_logic_vector(4 downto 0) := "10011";
constant CH_N           : std_logic_vector(4 downto 0) := "11100";


begin

    process (clk)
    begin
        if rising_edge(clk) then
            cnt <= cnt + 1;
        end if;
    end process;
    
    digit_to_display <= digit0 when cnt(15 downto 14) = "00" else
                        digit1 when cnt(15 downto 14) = "01" else
                        digit2 when cnt(15 downto 14) = "10" else
                        digit3;
    
    an <= "1110" when cnt(15 downto 14) = "00" else
          "1101" when cnt(15 downto 14) = "01" else
          "1011" when cnt(15 downto 14) = "10" else
          "0111";
    
    -- HEX-to-seven-segment decoder
          --   HEX:   in    STD_LOGIC_VECTOR (3 downto 0);
          --   LED:   out   STD_LOGIC_VECTOR (6 downto 0);
          --
          -- segment encoinputg
          --      0
          --     ---
          --  5 |   | 1
          --     ---   <- 6
          --  4 |   | 2
          --     ---
          --      3
          
    with digit_to_display select
         cat <= "1000000" when "00000",   --0
                "1111001" when "00001",   --1
                "0100100" when "00010",   --2
                "0110000" when "00011",   --3
                "0011001" when "00100",   --4
                "0010010" when "00101",   --5
                "0000010" when "00110",   --6
                "1111000" when "00111",   --7
                "0000000" when "01000",   --8
                "0010000" when "01001",   --9
                "0001000" when "01010",   --A
                "0000011" when "01011",   --b
                "1000110" when "01100",   --C
                "0100001" when "01101",   --d
                "0000110" when "01110",   --E
                "0001110" when "01111",   --F
                "0001001" when "10000",   --H
                "0101111" when "10001",   --r
                "1110111" when "10010",   --underscore
                "1101111" when "10011",   --i
                "1100011" when "10100",   --u
                "0000111" when "10101",   --t
                "0001100" when "11000",   --p
                "0100011" when "11001",   --o
                "0100111" when "11010",   --c
                "1111111" when "11011",   --blank
                "0101011" when "11100",   --N
                "0111111" when others;    --lines
end Behavioral;
