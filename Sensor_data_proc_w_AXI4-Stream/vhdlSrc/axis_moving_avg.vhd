library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.common_pkg.all;

entity axis_moving_avg is
    generic (
        DATA_WIDTH : integer := C_AXIS_DATA_WIDTH;
        WINDOW_SIZE: integer := C_AXIS_MOV_AVG_WINDOW_SIZE;
        SUM_WIDTH  : integer := C_AXIS_MOV_AVG_SUM_WIDTH;
        SHIFT_BITS : integer := C_AXIS_MOV_AVG_SHIFT_BITS 
    );
    port (
        aclk           : in  std_logic;
        rst            : in  std_logic;

        -- AXI4-Stream slave
        s_axis_tdata   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        s_axis_tvalid  : in  std_logic;
        s_axis_tready  : out std_logic;

        -- AXI4-Stream master
        m_axis_tdata   : out std_logic_vector(DATA_WIDTH-1 downto 0);
        m_axis_tvalid  : out std_logic;
        m_axis_tready  : in  std_logic
    );
end axis_moving_avg;

architecture Behavioral of axis_moving_avg is

    type sample_array_t is array (0 to WINDOW_SIZE-1) of unsigned(DATA_WIDTH-1 downto 0);

    signal samples   : sample_array_t := (others => (others => '0'));
    signal idx       : integer range 0 to WINDOW_SIZE-1 := 0;
    signal sum_reg   : unsigned(SUM_WIDTH-1 downto 0)   := (others => '0');

    signal data_reg  : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal valid_reg : std_logic := '0';

    signal s_axis_tready_int : std_logic;
begin

    s_axis_tready_int <= '1' when (valid_reg = '0') or (valid_reg = '1' and m_axis_tready = '1') else '0';

    process(aclk)
        variable new_sample  : unsigned(DATA_WIDTH-1 downto 0);
        variable old_sample  : unsigned(DATA_WIDTH-1 downto 0);
        variable sum_next    : unsigned(SUM_WIDTH-1 downto 0);
        variable avg         : unsigned(DATA_WIDTH-1 downto 0);
        variable next_idx    : integer range 0 to WINDOW_SIZE-1;
    begin
        if rising_edge(aclk) then
            if rst = '1' then
                samples   <= (others => (others => '0'));
                idx       <= 0;
                sum_reg   <= (others => '0');
                data_reg  <= (others => '0');
                valid_reg <= '0';
            else
                -- drop valid when downstream took the data
                if (valid_reg = '1') and (m_axis_tready = '1') then
                    valid_reg <= '0';
                end if;

                -- new sample?
                if (s_axis_tvalid = '1') and (s_axis_tready_int = '1') then
                    new_sample := unsigned(s_axis_tdata);
                    old_sample := samples(idx);

                    -- update circular buffer
                    samples(idx) <= new_sample;
                    if idx = WINDOW_SIZE-1 then
                        next_idx := 0;
                    else
                        next_idx := idx + 1;
                    end if;
                    idx <= next_idx;

                    -- running sum: sum_next = sum - oldest + new
                    sum_next := sum_reg - resize(old_sample, SUM_WIDTH) +
                                resize(new_sample, SUM_WIDTH);
                    sum_reg  <= sum_next;

                    -- average = sum_next >> SHIFT_BITS
                    avg := resize(sum_next(SUM_WIDTH-1 downto SHIFT_BITS), DATA_WIDTH);

                    data_reg  <= std_logic_vector(avg);
                    valid_reg <= '1';
                end if;
            end if;
        end if;
    end process;
    
    s_axis_tready <= s_axis_tready_int;
    m_axis_tdata  <= data_reg;
    m_axis_tvalid <= valid_reg;

end Behavioral;
