library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


library work;
use work.common_pkg.all;

entity axis_rr_interval is
    generic (
        COUNTER_WIDTH : integer := 16;  -- width of sample counter
        RR_WIDTH      : integer := 16;   -- width of RR output
        RR_MIN        : integer := 20   -- minimum RR in samples
    );
    port (
        aclk           : in  std_logic;
        rst            : in  std_logic;  -- active low

        -- AXI4-Stream slave (from axis_peak_detector)
        s_axis_tdata   : in  std_logic_vector(C_AXIS_DATA_WIDTH-1 downto 0); -- sample value (not actually needed, but passed through if you want)
        s_axis_tvalid  : in  std_logic;
        s_axis_tready  : out std_logic;
        s_axis_tuser_peak : in std_logic; -- '1' when this sample is a peak

        -- AXI4-Stream master (RR intervals out, in "samples")
        m_axis_tdata   : out std_logic_vector(RR_WIDTH-1 downto 0);
        m_axis_tvalid  : out std_logic;
        m_axis_tready  : in  std_logic
    );
end axis_rr_interval;

architecture Behavioral of axis_rr_interval is

    signal sample_cnt   : unsigned(COUNTER_WIDTH-1 downto 0) := (others => '0');
    signal last_peak_cnt: unsigned(COUNTER_WIDTH-1 downto 0) := (others => '0');
    signal have_last_peak : std_logic := '0';

    signal rr_reg       : std_logic_vector(RR_WIDTH-1 downto 0) := (others => '0');
    signal rr_valid_reg : std_logic := '0';
    signal s_axis_tready_int : std_logic;
    
    constant RR_MIN_U : unsigned(RR_WIDTH-1 downto 0) := to_unsigned(RR_MIN, RR_WIDTH);


begin

    -- Ready when buffer is free or downstream just consumed RR
    s_axis_tready_int <= '1' when (rr_valid_reg = '0') or
                              (rr_valid_reg = '1' and m_axis_tready = '1')
                     else '0';

    process(aclk)
        variable rr_val : unsigned(RR_WIDTH-1 downto 0);
    begin
        if rising_edge(aclk) then
            if rst = '1' then
                sample_cnt     <= (others => '0');
                last_peak_cnt  <= (others => '0');
                have_last_peak <= '0';
                rr_reg         <= (others => '0');
                rr_valid_reg   <= '0';
            else
                -- Clear valid when downstream accepts the RR
                if (rr_valid_reg = '1') and (m_axis_tready = '1') then
                    rr_valid_reg <= '0';
                end if;

                -- Accept new sample from input stream?
                if (s_axis_tvalid = '1') and (s_axis_tready_int = '1') then
                    -- Increment sample counter for each accepted sample
                    sample_cnt <= sample_cnt + 1;

                    if s_axis_tuser_peak = '1' then
                        if have_last_peak = '0' then
                            -- First peak: store position, no RR yet
                            last_peak_cnt  <= sample_cnt;
                            have_last_peak <= '1';
                        else
                            -- Subsequent peaks: compute RR = delta samples
                            rr_val := resize(sample_cnt - last_peak_cnt, RR_WIDTH);

                            if rr_val >= RR_MIN_U then
                                -- VALID RR
                                rr_reg       <= std_logic_vector(rr_val);
                                rr_valid_reg <= '1';
                            
                                -- accept this peak as the new reference
                                last_peak_cnt <= sample_cnt;
                            else
                                -- INVALID RR (too short)
                                -- ignore this peak, keep last_peak_cnt unchanged
                                -- sample_cnt continues counting as usual
                            end if;
                            
                        end if;
                    end if;

                end if; -- s_axis_tvalid & ready
            end if;
        end if;
    end process;
    s_axis_tready <= s_axis_tready_int;
    m_axis_tdata  <= rr_reg;
    m_axis_tvalid <= rr_valid_reg;

end Behavioral;
