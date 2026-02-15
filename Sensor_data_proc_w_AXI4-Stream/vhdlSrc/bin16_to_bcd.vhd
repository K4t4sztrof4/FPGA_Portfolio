library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity bin16_to_bcd is
    Port (
        bin_in  : in  std_logic_vector(15 downto 0);
        bcd_out : out std_logic_vector(15 downto 0)
    );
end bin16_to_bcd;

architecture Behavioral of bin16_to_bcd is
begin

    process(bin_in)
        variable value     : integer;
        variable thousands : integer;
        variable hundreds  : integer;
        variable tens      : integer;
        variable ones      : integer;
    begin
        -- Convert binary std_logic_vector to integer
        value := to_integer(unsigned(bin_in));

        -- Extract decimal digits
        thousands := (value / 1000) mod 10;
        hundreds  := (value / 100)  mod 10;
        tens       := (value / 10)   mod 10;
        ones       :=  value         mod 10;

        -- Pack into BCD (each nibble = 4 bits)
        bcd_out <=  std_logic_vector(to_unsigned(thousands, 4)) &
                    std_logic_vector(to_unsigned(hundreds, 4))  &
                    std_logic_vector(to_unsigned(tens, 4))      &
                    std_logic_vector(to_unsigned(ones, 4));
    end process;

end Behavioral;
