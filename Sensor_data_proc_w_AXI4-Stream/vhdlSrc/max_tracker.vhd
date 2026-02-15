library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity max_tracker is
    generic (
        DATA_WIDTH : integer := 16
    );
    port (
        clk           : in  std_logic;
        rst           : in  std_logic;  -- active high

        enable        : in  std_logic;  -- sticky enable

        signal_in     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        signal_valid  : in  std_logic;

        maximum_out   : out std_logic_vector(DATA_WIDTH-1 downto 0);
        maximum_valid : out std_logic
    );
end entity max_tracker;

architecture Behavioral of max_tracker is

    signal en_sticky       : std_logic := '0';
    signal max_reg         : unsigned(DATA_WIDTH-1 downto 0) := (others => '0');
    signal have_sample_reg : std_logic := '0';

begin

    process(clk)
        variable din_u : unsigned(DATA_WIDTH-1 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                en_sticky       <= '0';
                max_reg         <= (others => '0');
                have_sample_reg <= '0';
                maximum_out     <= (others => '0');
                maximum_valid   <= '0';
            else

                if enable = '1' then
                    en_sticky <= '1';
                end if;

                if (en_sticky = '1') and (signal_valid = '1') then
                    din_u := unsigned(signal_in);

                    if have_sample_reg = '0' then
                        -- First sample: initialize max
                        max_reg         <= din_u;
                        have_sample_reg <= '1';
                    else
                        if din_u > max_reg then
                            max_reg <= din_u;
                        end if;
                    end if;
                end if;

                maximum_out   <= std_logic_vector(max_reg);
                
                if have_sample_reg = '1' and en_sticky = '1' then
                    maximum_valid <= '1';
                else
                    maximum_valid <= '0';
                end if;

            end if;
        end if;
    end process;

end architecture Behavioral;
