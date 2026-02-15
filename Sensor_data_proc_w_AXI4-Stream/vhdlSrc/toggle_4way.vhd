library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity toggle_6way is
    Port (
        clk       : in  std_logic;
        rst       : in  std_logic;
        btn_pulse : in  std_logic;
        mode      : out std_logic_vector(3 downto 0)  -- 0000..1111
    );
end toggle_6way;

architecture Behavioral of toggle_6way is
    signal mode_reg : unsigned(3 downto 0) := (others => '0');
    constant modulo : integer := 7;
begin

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                mode_reg <= (others => '0');  -- start in mode 0
            else
                if btn_pulse = '1' then
                    -- increment modulo 4
                    mode_reg <= (mode_reg + 1) mod modulo;
                end if;
            end if;
        end if;
    end process;

    mode <= std_logic_vector(mode_reg);

end Behavioral;
