library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_axis_bpm_avg is
end tb_axis_bpm_avg;

architecture Behavioral of tb_axis_bpm_avg is

    constant BPM_WIDTH   : integer := 16;
    constant WINDOW_SIZE : integer := 4;  -- easier for testing

    signal aclk          : std_logic := '0';
    signal rst           : std_logic := '0';

    signal s_axis_tdata  : std_logic_vector(BPM_WIDTH-1 downto 0) := (others => '0');
    signal s_axis_tvalid : std_logic := '0';
    signal s_axis_tready : std_logic;

    signal m_axis_tdata  : std_logic_vector(BPM_WIDTH-1 downto 0);
    signal m_axis_tvalid : std_logic;
    signal m_axis_tready : std_logic := '1';  -- always ready

    type int_array is array (natural range <>) of integer;

    constant NUM_SAMPLES : integer := 10;
    -- Example BPM values (could be anything)
    constant stim_bpm    : int_array(0 to NUM_SAMPLES-1) :=
        (60, 70, 80, 90, 100, 110, 120, 130, 140, 150);

begin

    uut : entity work.axis_bpm_avg
        generic map (
            BPM_WIDTH   => BPM_WIDTH,
            WINDOW_SIZE => WINDOW_SIZE
        )
        port map (
            aclk          => aclk,
            rst           => rst,
            s_axis_tdata  => s_axis_tdata,
            s_axis_tvalid => s_axis_tvalid,
            s_axis_tready => s_axis_tready,
            m_axis_tdata  => m_axis_tdata,
            m_axis_tvalid => m_axis_tvalid,
            m_axis_tready => m_axis_tready
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

        type int_array_window is array (natural range <>) of integer;
        variable window_g      : int_array_window(0 to WINDOW_SIZE-1) := (others => 0);
        variable index_g       : integer range 0 to WINDOW_SIZE-1 := 0;
        variable filled_count_g: integer range 0 to WINDOW_SIZE   := 0;
        variable sum_acc_g     : integer := 0;

        variable in_bpm        : integer;
        variable new_sum_g     : integer;
        variable avg_int_g     : integer;
        variable expected_valid: boolean;
        variable i             : integer;
        variable got_bpm       : integer;
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

            s_axis_tdata  <= std_logic_vector(to_unsigned(stim_bpm(i), BPM_WIDTH));
            s_axis_tvalid <= '1';

            wait until rising_edge(aclk);


            s_axis_tvalid <= '0';

            in_bpm    := stim_bpm(i);
            expected_valid := false;

            if filled_count_g < WINDOW_SIZE then

                new_sum_g              := sum_acc_g + in_bpm;
                window_g(index_g)      := in_bpm;
                sum_acc_g              := new_sum_g;
                filled_count_g         := filled_count_g + 1;
                index_g                := (index_g + 1) mod WINDOW_SIZE;

                if filled_count_g = WINDOW_SIZE then
                    avg_int_g       := new_sum_g / WINDOW_SIZE;
                    expected_valid  := true;
                end if;
            else
                new_sum_g             := sum_acc_g - window_g(index_g) + in_bpm;
                sum_acc_g             := new_sum_g;
                window_g(index_g)     := in_bpm;
                index_g               := (index_g + 1) mod WINDOW_SIZE;

                avg_int_g      := new_sum_g / WINDOW_SIZE;
                expected_valid := true;
            end if;

            wait until rising_edge(aclk);

            if expected_valid then

                assert m_axis_tvalid = '1'
                    report "Expected m_axis_tvalid='1' at sample index " & integer'image(i)
                    severity error;

                got_bpm := to_integer(unsigned(m_axis_tdata));

                assert got_bpm = avg_int_g
                    report "Average BPM mismatch at sample index " & integer'image(i) &
                           ". Windowed BPM average expected=" & integer'image(avg_int_g) &
                           " Got=" & integer'image(got_bpm)
                    severity error;

                report "Sample " & integer'image(i) &
                       " OK: avg BPM = " & integer'image(got_bpm)
                    severity note;
            else

                assert m_axis_tvalid = '0'
                    report "m_axis_tvalid should be '0' before window is full (sample index " &
                           integer'image(i) & ")"
                    severity error;
            end if;

        end loop;
        report "All BPM samples applied, tb_axis_bpm_avg finished successfully." severity note;
        wait;
    end process;

end Behavioral;
