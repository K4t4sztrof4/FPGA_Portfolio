library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_axis_rr_interval is
end tb_axis_rr_interval;

architecture Behavioral of tb_axis_rr_interval is

    constant COUNTER_WIDTH : integer := 16;
    constant RR_WIDTH      : integer := 16;

    signal aclk              : std_logic := '0';
    signal rst               : std_logic := '0';  -- active high in RTL

    signal s_axis_tdata      : std_logic_vector(15 downto 0) := (others => '0');
    signal s_axis_tvalid     : std_logic := '0';
    signal s_axis_tready     : std_logic;
    signal s_axis_tuser_peak : std_logic := '0';

    signal m_axis_tdata      : std_logic_vector(RR_WIDTH-1 downto 0);
    signal m_axis_tvalid     : std_logic;
    signal m_axis_tready     : std_logic := '1';  -- always ready in this TB

    type int_array is array (natural range <>) of integer;
    type bit_array is array (natural range <>) of std_logic;

    constant NUM_SAMPLES : integer := 12;

    constant stim_values : int_array(0 to NUM_SAMPLES-1) :=
        ( 10, 20, 30, 40, 50, 60, 70, 80, 90,100,110,120 );

    -- Mark peaks (for example at indices 3, 7, 10)
    -- 0-based indices:
    --   index 3  -> first peak
    --   index 7  -> second peak  (RR1)
    --   index 10 -> third peak   (RR2)
    constant stim_peaks : bit_array(0 to NUM_SAMPLES-1) :=
        ( '0', '0', '0', '1',   -- 3
          '0', '0', '0', '1',   -- 7
          '0', '0', '1', '0' ); -- 10

begin

    uut : entity work.axis_rr_interval
        generic map (
            COUNTER_WIDTH => COUNTER_WIDTH,
            RR_WIDTH      => RR_WIDTH
        )
        port map (
            aclk              => aclk,
            rst               => rst,
            s_axis_tdata      => s_axis_tdata,
            s_axis_tvalid     => s_axis_tvalid,
            s_axis_tready     => s_axis_tready,
            s_axis_tuser_peak => s_axis_tuser_peak,
            m_axis_tdata      => m_axis_tdata,
            m_axis_tvalid     => m_axis_tvalid,
            m_axis_tready     => m_axis_tready
        );


    clk_process : process
    begin
        while true loop
            aclk <= '0';
            wait for 5 ns;
            aclk <= '1';
            wait for 5 ns;
        end loop;
    end process;

    stim_proc : process
        variable sample_cnt_g      : integer := 0;
        variable last_peak_cnt_g   : integer := 0;
        variable have_last_peak_g  : boolean := false;

        variable expected_rr_valid : boolean;
        variable expected_rr_value : integer;

        variable old_cnt           : integer;
        variable rr_int            : integer;

        variable i                 : integer;
    begin

        rst <= '1';
        s_axis_tvalid     <= '0';
        s_axis_tuser_peak <= '0';
        wait for 40 ns;
        wait until rising_edge(aclk);
        rst <= '0';
        wait until rising_edge(aclk);


        for i in 0 to NUM_SAMPLES-1 loop

            wait until rising_edge(aclk);
            while s_axis_tready = '0' loop
                wait until rising_edge(aclk);
            end loop;

            s_axis_tdata      <= std_logic_vector(to_unsigned(stim_values(i), 16));
            s_axis_tuser_peak <= stim_peaks(i);
            s_axis_tvalid     <= '1';

            wait until rising_edge(aclk);

            s_axis_tvalid <= '0';
            s_axis_tuser_peak <= '0';

            old_cnt := sample_cnt_g;          -- this is "current" sample_cnt
            sample_cnt_g := sample_cnt_g + 1; -- matches sample_cnt <= sample_cnt + 1

            expected_rr_valid := false;

            if stim_peaks(i) = '1' then
                if not have_last_peak_g then
                    --first peak: store position, no RR yet
                    last_peak_cnt_g  := old_cnt;
                    have_last_peak_g := true;
                else
                    --following peaks: RR = old_cnt - last_peak_cnt
                    expected_rr_value := old_cnt - last_peak_cnt_g;
                    last_peak_cnt_g   := old_cnt;
                    expected_rr_valid := true;
                end if;
            end if;

            wait until rising_edge(aclk);

            if expected_rr_valid then
                assert m_axis_tvalid = '1'
                    report "Expected m_axis_tvalid='1' at sample index " &
                           integer'image(i)
                    severity error;

                rr_int := to_integer(unsigned(m_axis_tdata));

                assert rr_int = expected_rr_value
                    report "RR mismatch at sample " & integer'image(i) &
                           ". Expected RR=" & integer'image(expected_rr_value) &
                           " Got RR=" & integer'image(rr_int)
                    severity error;

                report "RR OK at peak sample index " & integer'image(i) &
                       ". RR=" & integer'image(rr_int)
                    severity note;
            else
                --no RR expected -> no valid or leftover from previous;
                null;
            end if;

        end loop;

        report "All samples applied, tb_axis_rr_interval finished." severity note;
        wait;
    end process;

end Behavioral;
