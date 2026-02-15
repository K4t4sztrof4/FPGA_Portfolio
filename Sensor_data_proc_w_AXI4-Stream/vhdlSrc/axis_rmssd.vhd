library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity axis_rmssd is
    generic (
        RR_WIDTH    : integer := 16;   -- width of RR input
        RMSSD_WIDTH : integer := 16;   -- width of RMSSD output
        WINDOW_SIZE : integer := 16    -- number of RR samples per block
    );
    port (
        aclk          : in  std_logic;
        rst           : in  std_logic;  -- active high

        -- AXI4-Stream slave (RR intervals in "samples")
        s_axis_tdata  : in  std_logic_vector(RR_WIDTH-1 downto 0);
        s_axis_tvalid : in  std_logic;
        s_axis_tready : out std_logic;

        -- AXI4-Stream master (RMSSD out)
        m_axis_tdata  : out std_logic_vector(RMSSD_WIDTH-1 downto 0);
        m_axis_tvalid : out std_logic;
        m_axis_tready : in  std_logic
    );
end axis_rmssd;

architecture Behavioral of axis_rmssd is

    -- Simple integer square root using unsigned input
    function isqrt(n : unsigned) return unsigned is
        variable x0  : unsigned(n'length-1 downto 0) := (others => '0');
        variable x1  : unsigned(n'length-1 downto 0) := (others => '0');
        variable tmp : unsigned(n'length-1 downto 0);
    begin
        -- Binary restoring iteration
        for i in n'length-1 downto 0 loop
            tmp := x1;
            tmp(i) := '1';
            if tmp * tmp <= n then
                x1 := tmp;
            end if;
        end loop;
        return x1;
    end function;

    constant SQ_WIDTH : integer := 32;  -- internal width for sum and mean

    signal prev_rr        : integer := 0;
    signal have_prev_rr   : std_logic := '0';

    signal diff_count     : integer range 0 to WINDOW_SIZE := 0;
    signal sum_sq         : integer := 0;

    signal rmssd_reg      : std_logic_vector(RMSSD_WIDTH-1 downto 0) := (others => '0');
    signal rmssd_valid_reg: std_logic := '0';

    signal s_axis_tready_int : std_logic;

begin

    -- Ready when output buffer is free or just consumed
    s_axis_tready_int <= '1' when (rmssd_valid_reg = '0') or
                                (rmssd_valid_reg = '1' and m_axis_tready = '1')
                         else '0';

    process(aclk)
        variable rr_curr      : integer;
        variable diff         : integer;
        variable diff_abs     : integer;
        variable diff_sq      : integer;
        variable mean_sq      : integer;
        variable mean_sq_u    : unsigned(SQ_WIDTH-1 downto 0);
        variable rmssd_u      : unsigned(SQ_WIDTH-1 downto 0);
        variable rmssd_int    : integer;
        constant ONE          : integer := 1;
    begin
        if rising_edge(aclk) then
            if rst = '1' then
                prev_rr        <= 0;
                have_prev_rr   <= '0';
                diff_count     <= 0;
                sum_sq         <= 0;
                rmssd_reg      <= (others => '0');
                rmssd_valid_reg<= '0';
            else
                -- Drop valid when downstream consumes RMSSD
                if (rmssd_valid_reg = '1') and (m_axis_tready = '1') then
                    rmssd_valid_reg <= '0';
                end if;

                -- New RR sample?
                if (s_axis_tvalid = '1') and (s_axis_tready_int = '1') then
                    rr_curr := to_integer(unsigned(s_axis_tdata));

                    if have_prev_rr = '1' then
                        -- diff = |RR_curr - RR_prev|
                        diff := rr_curr - prev_rr;
                        if diff < 0 then
                            diff_abs := -diff;
                        else
                            diff_abs := diff;
                        end if;

                        diff_sq  := diff_abs * diff_abs;
                        sum_sq   <= sum_sq + diff_sq;
                        diff_count <= diff_count + 1;

                        -- When we have WINDOW_SIZE-1 diffs -> compute RMSSD
                        if diff_count + 1 = WINDOW_SIZE then
                            if (WINDOW_SIZE - 1) > 0 then
                                mean_sq := sum_sq + diff_sq; -- sum_sq was old, plus current
                                mean_sq := mean_sq / (WINDOW_SIZE - 1);
                            else
                                mean_sq := 0;
                            end if;

                            if mean_sq < 0 then
                                mean_sq := 0;
                            end if;

                            -- Convert to unsigned, run isqrt, clamp to RMSSD_WIDTH
                            mean_sq_u := to_unsigned(mean_sq, SQ_WIDTH);
                            rmssd_u   := isqrt(mean_sq_u);

                            if to_integer(rmssd_u) > (2**RMSSD_WIDTH - 1) then
                                rmssd_int := 2**RMSSD_WIDTH - 1;
                            else
                                rmssd_int := to_integer(rmssd_u);
                            end if;

                            rmssd_reg       <= std_logic_vector(to_unsigned(rmssd_int, RMSSD_WIDTH));
                            rmssd_valid_reg <= '1';

                            -- Reset window accumulators, keep last RR as previous
                            sum_sq       <= 0;
                            diff_count   <= 0;
                            have_prev_rr <= '0'; -- next RR starts a new block
                        end if;
                    end if;

                    -- Update previous RR
                    prev_rr      <= rr_curr;
                    have_prev_rr <= '1';
                end if;
            end if;
        end if;
    end process;

    s_axis_tready <= s_axis_tready_int;
    m_axis_tdata  <= rmssd_reg;
    m_axis_tvalid <= rmssd_valid_reg;

end Behavioral;
