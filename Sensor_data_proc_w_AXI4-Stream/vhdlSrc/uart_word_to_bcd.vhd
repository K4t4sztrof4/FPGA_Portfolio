library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity uart_word_to_bcd is
    Port (
        clk            : in  STD_LOGIC;
        rst            : in  STD_LOGIC;

        -- from uart_word_assembler
        word16_in      : in  STD_LOGIC_VECTOR(15 downto 0);
        word_valid_in  : in  STD_LOGIC;

        -- BCD result
        bcd_out        : out STD_LOGIC_VECTOR(15 downto 0);
        bcd_valid      : out STD_LOGIC
    );
end uart_word_to_bcd;

architecture Behavioral of uart_word_to_bcd is

    -- your existing converter
    component bin16_to_bcd is
      Port (
            bin_in  : in  STD_LOGIC_VECTOR(15 downto 0);
            bcd_out : out STD_LOGIC_VECTOR(15 downto 0)
      );
    end component;

    signal bcd_comb       : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
    signal bcd_reg        : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
    signal bcd_valid_reg  : STD_LOGIC := '0';

begin

    -- combinational conversion from current word16_in
    comb_conv: bin16_to_bcd
        port map (
            bin_in  => word16_in,
            bcd_out => bcd_comb
        );

    -- register BCD output and generate valid pulse
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                bcd_reg       <= (others => '0');
                bcd_valid_reg <= '0';
            else
                -- default: no new word
                bcd_valid_reg <= '0';

                -- on each new UART word
                if word_valid_in = '1' then
                    bcd_reg       <= bcd_comb;  -- latch converted BCD
                    bcd_valid_reg <= '1';       -- 1-clk pulse
                end if;
            end if;
        end if;
    end process;

    bcd_out   <= bcd_reg;
    bcd_valid <= bcd_valid_reg;

end Behavioral;
