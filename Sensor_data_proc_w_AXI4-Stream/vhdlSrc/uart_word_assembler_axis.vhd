library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.common_pkg.all;

entity uart_word_assembler_axis is
    Port (
        aclk        : in  STD_LOGIC;
        rst     : in  STD_LOGIC;  -- active low normally, made it active high

        --from uart bit sampler
        rx_ready    : in  STD_LOGIC;
        rx_byte     : in  STD_LOGIC_VECTOR(7 downto 0);

        --axi4 stream master interface
        m_axis_tdata  : out STD_LOGIC_VECTOR(15 downto 0);
        m_axis_tvalid : out STD_LOGIC;
        m_axis_tready : in  STD_LOGIC
    );
end uart_word_assembler_axis;

architecture Behavioral of uart_word_assembler_axis is
component uart_word_assembler is
    Port (
        clk        : in  STD_LOGIC;
        rst        : in  STD_LOGIC;
        rx_ready   : in  STD_LOGIC;
        rx_byte    : in  STD_LOGIC_VECTOR (7 downto 0);
        word16     : out STD_LOGIC_VECTOR (15 downto 0);
        word_valid : out STD_LOGIC
    );
end component;

signal word16_int, word16_prev, data_reg      : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
signal word_valid_int, have_data : STD_LOGIC := '0';

begin

u_word_asm: uart_word_assembler
    port map (
        clk        => aclk,
        rst        => rst,
        rx_ready   => rx_ready,
        rx_byte    => rx_byte,
        word16     => word16_int,
        word_valid => word_valid_int
    );

process(aclk)
begin
    if rising_edge(aclk) then
        if rst = '1' then
            data_reg  <= (others => '0');
            have_data <= '0';
        else
            -- if we receive a new 16-bit word from the assembler, latch it
            if (word_valid_int = '1') and
               (word16_int /= word16_prev) and
               (have_data = '0') then

                data_reg    <= word16_int;
                word16_prev <= word16_int;
                have_data   <= '1';
            end if;

            -- if we currently have data and the AXI sink accepted it,
            -- drop have_data to allow next word to be loaded.
            if (have_data = '1') and (m_axis_tready = '1') then
                have_data <= '0';
            end if;
        end if;
    end if;
end process;

m_axis_tdata  <= data_reg;
m_axis_tvalid <= have_data;

end Behavioral;
