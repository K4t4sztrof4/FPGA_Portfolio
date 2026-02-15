library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.common_pkg.all;

entity axis_peak_detector is
    generic (
        DATA_WIDTH : integer := C_AXIS_DATA_WIDTH;
        THRESHOLD  : integer := C_AXIS_PEAK_DET_THRESHOLD -- ignore tiny peaks below this
    );
    port (
        aclk            : in  std_logic;
        rst             : in  std_logic;

        -- AXI4-Stream slave
        s_axis_tdata    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        s_axis_tvalid   : in  std_logic;
        s_axis_tready   : out std_logic;

        -- AXI4-Stream master
        m_axis_tdata    : out std_logic_vector(DATA_WIDTH-1 downto 0);
        m_axis_tvalid   : out std_logic;
        m_axis_tready   : in  std_logic;

        -- peak flag (TUSER[0])
        m_axis_tuser_peak : out std_logic
    );
end axis_peak_detector;

architecture Behavioral of axis_peak_detector is


    -- 3-sample window
    signal x_prev2  : unsigned(DATA_WIDTH-1 downto 0) := (others => '0');
    signal x_prev1  : unsigned(DATA_WIDTH-1 downto 0) := (others => '0');
    signal x_curr   : unsigned(DATA_WIDTH-1 downto 0) := (others => '0');

    signal sample_count : integer range 0 to 3 := 0; -- to know when window is filled

    signal data_reg  : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal peak_reg  : std_logic := '0';
    signal valid_reg : std_logic := '0';

    constant THRESHOLD_U : unsigned(DATA_WIDTH-1 downto 0) :=
        to_unsigned(THRESHOLD, DATA_WIDTH);
    signal s_axis_tready_int : std_logic;

begin

    s_axis_tready_int <= '1' when (valid_reg = '0') or (valid_reg = '1' and m_axis_tready = '1') else '0';

    process(aclk)
        variable in_sample   : unsigned(DATA_WIDTH-1 downto 0);
        variable is_peak     : std_logic;
        variable have_window : boolean;
    begin
        if rising_edge(aclk) then
            if rst = '1' then
                x_prev2      <= (others => '0');
                x_prev1      <= (others => '0');
                x_curr       <= (others => '0');
                sample_count <= 0;
                data_reg     <= (others => '0');
                peak_reg     <= '0';
                valid_reg    <= '0';
            else
                -- drop valid when downstream took the data
                if (valid_reg = '1') and (m_axis_tready = '1') then
                    valid_reg <= '0';
                end if;

                if (s_axis_tvalid = '1') and (s_axis_tready_int = '1') then
                    in_sample := unsigned(s_axis_tdata);

                    -- shift window
                    x_prev2 <= x_prev1;
                    x_prev1 <= x_curr;
                    x_curr  <= in_sample;

                    if sample_count < 3 then
                        sample_count <= sample_count + 1;
                    end if;

                    have_window := (sample_count >= 2);  -- after 3rd sample

                    is_peak := '0';

                    if have_window then
                        -- middle sample is x_prev1
                        if (x_prev1 > x_prev2) and
                           (x_prev1 >= in_sample) and
                           (x_prev1 > THRESHOLD_U) then
                            is_peak := '1';
                        end if;

                        data_reg <= std_logic_vector(x_prev1);
                    else
                        -- not enough history yet: output 0, no peak
                        data_reg <= (others => '0');
                        is_peak  := '0';
                    end if;

                    peak_reg  <= is_peak;
                    valid_reg <= '1';
                end if;
            end if;
        end if;
    end process;
    s_axis_tready <= s_axis_tready_int;
    m_axis_tdata      <= data_reg;
    m_axis_tvalid     <= valid_reg;
    m_axis_tuser_peak <= peak_reg;

end Behavioral;
