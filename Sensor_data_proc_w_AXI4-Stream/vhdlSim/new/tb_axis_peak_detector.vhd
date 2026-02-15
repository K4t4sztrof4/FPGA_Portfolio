library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_axis_peak_detector is
end tb_axis_peak_detector;

architecture Behavioral of tb_axis_peak_detector is

    constant DATA_WIDTH : integer := 16;
    constant THRESHOLD  : integer := 10;

    signal aclk            : std_logic := '0';
    signal rst             : std_logic := '0';

    signal s_axis_tdata    : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal s_axis_tvalid   : std_logic := '0';
    signal s_axis_tready   : std_logic;

    signal m_axis_tdata      : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal m_axis_tvalid     : std_logic;
    signal m_axis_tready     : std_logic := '1';  -- always ready in this TB
    signal m_axis_tuser_peak : std_logic;

    type int_array is array (natural range <>) of integer;
    constant NUM_SAMPLES : integer := 11;
    constant stim_values : int_array(0 to NUM_SAMPLES-1) :=
        (  0,   5,  20,  15,   3,
          50,  40,  20,  10,  60,
          30 );

    type slv_array  is array (natural range <>) of std_logic_vector(DATA_WIDTH-1 downto 0);
    type bit_array  is array (natural range <>) of std_logic;

    signal expected_data  : slv_array(0 to NUM_SAMPLES-1);
    signal expected_peak  : bit_array(0 to NUM_SAMPLES-1);

begin

    uut : entity work.axis_peak_detector
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            THRESHOLD  => THRESHOLD
        )
        port map (
            aclk            => aclk,
            rst             => rst,
            s_axis_tdata    => s_axis_tdata,
            s_axis_tvalid   => s_axis_tvalid,
            s_axis_tready   => s_axis_tready,
            m_axis_tdata    => m_axis_tdata,
            m_axis_tvalid   => m_axis_tvalid,
            m_axis_tready   => m_axis_tready,
            m_axis_tuser_peak => m_axis_tuser_peak
        );


    --100 MHz  clk->10ns
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
        -- Golden model state
        variable x_prev2      : unsigned(DATA_WIDTH-1 downto 0) := (others => '0');
        variable x_prev1      : unsigned(DATA_WIDTH-1 downto 0) := (others => '0');
        variable x_curr       : unsigned(DATA_WIDTH-1 downto 0) := (others => '0');
        variable sample_count : integer range 0 to 3 := 0;

        variable in_sample    : unsigned(DATA_WIDTH-1 downto 0);
        variable have_window  : boolean;
        variable is_peak_v    : std_logic;
        variable exp_data_v   : std_logic_vector(DATA_WIDTH-1 downto 0);

        constant THRESHOLD_U  : unsigned(DATA_WIDTH-1 downto 0) :=
                                   to_unsigned(THRESHOLD, DATA_WIDTH);

        variable i : integer;
    begin

        rst <= '1';
        s_axis_tvalid <= '0';
        wait for 40 ns;
        wait until rising_edge(aclk);
        rst <= '0';
        wait until rising_edge(aclk);

        for i in 0 to NUM_SAMPLES-1 loop

            wait until rising_edge(aclk);
            while s_axis_tready = '0' loop
                wait until rising_edge(aclk);
            end loop;


            s_axis_tdata  <= std_logic_vector(to_unsigned(stim_values(i), DATA_WIDTH));
            s_axis_tvalid <= '1';

            wait until rising_edge(aclk);

            in_sample := unsigned(s_axis_tdata);

            x_prev2 := x_prev1;
            x_prev1 := x_curr;
            x_curr  := in_sample;

            if sample_count < 3 then
                sample_count := sample_count + 1;
            end if;

            have_window := (sample_count >= 2);  -- after 3rd sample

            is_peak_v := '0';

            if have_window then
                -- middle sample is x_prev1
                if (x_prev1 > x_prev2) and
                   (x_prev1 >= in_sample) and
                   (x_prev1 > THRESHOLD_U) then
                    is_peak_v := '1';
                end if;
                exp_data_v := std_logic_vector(x_prev1);
            else
                exp_data_v := (others => '0');
                is_peak_v  := '0';
            end if;

            expected_data(i) <= exp_data_v;
            expected_peak(i) <= is_peak_v;

            -- Deassert tvalid after handshake
            s_axis_tvalid <= '0';

            wait until rising_edge(aclk);

            --expect an output for each input sample, because DUT sets valid_reg on every accepted sample
            assert m_axis_tvalid = '1'
                report "Expected m_axis_tvalid='1' at sample index " & integer'image(i)
                severity error;
            --comp data
            assert m_axis_tdata = expected_data(i)
                report "DATA mismatch at sample " & integer'image(i) &
                       ". Stim=" & integer'image(stim_values(i)) &
                       " Expected=" & integer'image(to_integer(unsigned(expected_data(i)))) &
                       " Got=" & integer'image(to_integer(unsigned(m_axis_tdata)))
                severity error;

            --comp peak flag
            assert m_axis_tuser_peak = expected_peak(i)
                report "PEAK flag mismatch at sample " & integer'image(i) &
                       ". Stim=" & integer'image(stim_values(i)) &
                       " Expected peak=" & std_logic'image(expected_peak(i)) &
                       " Got=" & std_logic'image(m_axis_tuser_peak)
                severity error;


            if expected_peak(i) = '1' then
                report "Peak detected correctly at sample " & integer'image(i)
                    severity note;
            end if;

        end loop;

        report "All samples applied, testbench finished successfully." severity note;
        wait;
    end process;

end Behavioral;
