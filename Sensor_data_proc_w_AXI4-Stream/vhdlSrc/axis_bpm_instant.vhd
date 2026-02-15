library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity axis_bpm_instant is
    generic (
        SAMPLE_RATE : integer := 100;  -- samples per second (send interval constant in arduino code)
        RR_WIDTH    : integer := 16;    -- width of BPM output
        BPM_WIDTH   : integer := 16    -- width of BPM output
    );
    port (
        aclk           : in  std_logic;
        rst            : in  std_logic;

        -- AXI4-Stream slave (RR intervals in "samples")
        s_axis_tdata   : in  std_logic_vector(RR_WIDTH-1 downto 0); -- RR value
        s_axis_tvalid  : in  std_logic;
        s_axis_tready  : out std_logic;

        -- AXI4-Stream master (BPM out as integer)
        m_axis_tdata   : out std_logic_vector(BPM_WIDTH-1 downto 0);
        m_axis_tvalid  : out std_logic;
        m_axis_tready  : in  std_logic
    );
end axis_bpm_instant;

architecture Behavioral of axis_bpm_instant is

    signal bpm_reg      : std_logic_vector(BPM_WIDTH-1 downto 0) := (others => '0');
    signal bpm_valid_reg: std_logic := '0';
    signal s_axis_tready_int : std_logic;

begin

    -- Ready when BPM buffer is free or downstream just took data
    s_axis_tready_int <= '1' when (bpm_valid_reg = '0') or
                              (bpm_valid_reg = '1' and m_axis_tready = '1')
                     else '0';

    process(aclk)
        variable rr_samples : integer;
        variable bpm_int    : integer;
        constant K          : integer := 60 * SAMPLE_RATE;  -- precompute constant
    begin
        if rising_edge(aclk) then
            if rst = '1' then
                bpm_reg       <= (others => '0');
                bpm_valid_reg <= '0';
            else
                -- Drop valid when downstream consumes the BPM
                if (bpm_valid_reg = '1') and (m_axis_tready = '1') then
                    bpm_valid_reg <= '0';
                end if;

                -- New RR value?
                if (s_axis_tvalid = '1') and (s_axis_tready_int = '1') then
                    rr_samples := to_integer(unsigned(s_axis_tdata));

                    if rr_samples > 0 then
                        -- BPM = (60 * Fs) / RR_samples
                        bpm_int := K / rr_samples;

                        -- Optional: clamp BPM to a reasonable range, e.g. [0, 220]
                        if bpm_int < 0 then
                            bpm_int := 0;
                        elsif bpm_int > (2**BPM_WIDTH-1) then
                            bpm_int := 2**BPM_WIDTH-1;
                        end if;
                    else
                        bpm_int := 0;
                    end if;

                    bpm_reg       <= std_logic_vector(to_unsigned(bpm_int, BPM_WIDTH));
                    bpm_valid_reg <= '1';
                end if;
            end if;
        end if;
    end process;

    m_axis_tdata  <= bpm_reg;
    m_axis_tvalid <= bpm_valid_reg;
    s_axis_tready <= s_axis_tready_int;

end Behavioral;
