library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity uart_word_assembler is
    Port ( clk : in STD_LOGIC;
           rst : in STD_LOGIC;
           rx_ready : in STD_LOGIC;
           rx_byte : in STD_LOGIC_VECTOR (7 downto 0);
           word16 : out STD_LOGIC_VECTOR (15 downto 0);
           word_valid : out STD_LOGIC);
end uart_word_assembler;

architecture Behavioral of uart_word_assembler is
    signal hi_byte   : std_logic_vector(7 downto 0) := (others => '0');
    signal lo_byte   : std_logic_vector(7 downto 0) := (others => '0');
    signal word16_inter    : std_logic_vector(15 downto 0) := (others => '0');

    type rx_state_t is (WAIT_HI, WAIT_LO);
    signal rx_state  : rx_state_t := WAIT_HI;
    signal word_valid_inter : std_logic := '0';
begin

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                rx_state        <= WAIT_HI;
                hi_byte         <= (others => '0');
                lo_byte         <= (others => '0');
                word16_inter    <= (others => '0');
                word_valid_inter<= '0';

            else
                case rx_state is

                    when WAIT_HI =>
                        if rx_ready = '1' then
                            hi_byte         <= rx_byte;
                            rx_state        <= WAIT_LO;
                            -- starting new word -> no longer valid
                            word_valid_inter<= '0';
                        end if;

                    when WAIT_LO =>
                        if rx_ready = '1' then
                            lo_byte         <= rx_byte;
                            word16_inter    <= hi_byte & rx_byte;
                            word_valid_inter<= '1';
                            rx_state        <= WAIT_HI;
                        end if;

                end case;
            end if;
        end if;
    end process;

    word16     <= word16_inter;
    word_valid <= word_valid_inter;
end Behavioral;

