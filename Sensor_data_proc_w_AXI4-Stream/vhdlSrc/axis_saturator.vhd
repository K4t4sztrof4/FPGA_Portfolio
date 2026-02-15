library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.common_pkg.all;

entity axis_saturator is
    generic (
        DATA_WIDTH : integer := C_AXIS_DATA_WIDTH;
        MIN_VAL    : integer := C_IR_MIN;
        MAX_VAL    : integer := C_IR_MAX
    );
    port (
        aclk           : in  std_logic;
        rst        : in  std_logic; --active high

        s_axis_tdata   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        s_axis_tvalid  : in  std_logic;
        s_axis_tready  : out std_logic;

        m_axis_tdata   : out std_logic_vector(DATA_WIDTH-1 downto 0);
        m_axis_tvalid  : out std_logic;
        m_axis_tready  : in  std_logic
    );
end axis_saturator;

architecture Behavioral of axis_saturator is


type state_type is (S_READ, S_WRITE);
signal state : state_type := S_READ;

signal result : STD_LOGIC_VECTOR (DATA_WIDTH-1 downto 0) := (others => '0');

signal a_ready : STD_LOGIC := '0';
signal internal_ready, external_ready, inputs_valid : STD_LOGIC := '0';

constant MIN_VAL_U : unsigned(DATA_WIDTH-1 downto 0) := 
    to_unsigned(MIN_VAL, DATA_WIDTH);

constant MAX_VAL_U : unsigned(DATA_WIDTH-1 downto 0) := 
    to_unsigned(MAX_VAL, DATA_WIDTH);
signal data_in : unsigned(DATA_WIDTH-1 downto 0);

begin
    s_axis_tready <= external_ready;
    
    internal_ready <= '1' when state = S_READ else '0';
    inputs_valid <= s_axis_tvalid;
    external_ready <= internal_ready and inputs_valid;
    data_in <= unsigned(s_axis_tdata);
    m_axis_tvalid <= '1' when state = S_WRITE else '0';
    m_axis_tdata <= result;
    
    process(aclk)
    begin
        if rising_edge(aclk) then
            case state is
                when S_READ =>
                    if external_ready = '1' and inputs_valid = '1' then
                        if data_in  < MIN_VAL_U then
                            result <= std_logic_vector(MIN_VAL_U);
                        elsif data_in  > MAX_VAL_U then
                            result <= std_logic_vector(MAX_VAL_U);
                        else 
                            result <= s_axis_tdata;
                        end if;
                        state <= S_WRITE;
                    end if;
                when S_WRITE =>
                    if m_axis_tready = '1' then
                        state <= S_READ;
                    end if;
            end case;
        end if;
    end process;

end Behavioral;
