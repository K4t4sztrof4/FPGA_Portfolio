library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.math_real.all;

entity tb_axis_rmssd is
end tb_axis_rmssd;

architecture Behavioral of tb_axis_rmssd is

    constant RR_WIDTH    : integer := 16;
    constant RMSSD_WIDTH : integer := 16;
    constant WINDOW_SIZE : integer := 4;   -- smaller window for easier testing

    signal aclk          : std_logic := '0';
    signal rst           : std_logic := '0';

    signal s_axis_tdata  : std_logic_vector(RR_WIDTH-1 downto 0) := (others => '0');
    signal s_axis_tvalid : std_logic := '0';
    signal s_axis_tready : std_logic;

    signal m_axis_tdata  : std_logic_vector(RMSSD_WIDTH-1 downto 0);
    signal m_axis_tvalid : std_logic;
    signal m_axis_tready : std_logic := '1';   -- always ready

    type int_array is array (natural range <>) of integer;

    constant NUM_SAMPLES : integer := 10;
    --some reasonable RR values
    constant rr_values   : int_array(0 to NUM_SAMPLES-1) :=
        (800, 810, 790, 805, 795, 810, 820, 800, 790, 805);

begin

    uut : entity work.axis_rmssd
        generic map (
            RR_WIDTH    => RR_WIDTH,
            RMSSD_WIDTH => RMSSD_WIDTH,
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
        variable prev_rr_g       : integer := 0;
        variable have_prev_rr_g  : boolean := false;

        variable diff_count_g    : integer := 0;
        variable sum_sq_g        : integer := 0;

        variable rr_curr         : integer;
        variable diff            : integer;
        variable diff_abs        : integer;
        variable diff_sq         : integer;

        variable mean_sq         : integer;
        variable rmssd_expected  : integer;
        variable expect_valid    : boolean := false;

        variable i               : integer;
        variable got_rmssd       : integer;
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

            s_axis_tdata  <= std_logic_vector(to_unsigned(rr_values(i), RR_WIDTH));
            s_axis_tvalid <= '1';

            wait until rising_edge(aclk);


            s_axis_tvalid <= '0';

            rr_curr := rr_values(i);

            if have_prev_rr_g then
                -- diff = |RR_curr - RR_prev|
                diff := rr_curr - prev_rr_g;
                if diff < 0 then
                    diff_abs := -diff;
                else
                    diff_abs := diff;
                end if;

                diff_sq      := diff_abs * diff_abs;
                sum_sq_g     := sum_sq_g + diff_sq;
                diff_count_g := diff_count_g + 1;

                if diff_count_g = WINDOW_SIZE then
                    if (WINDOW_SIZE - 1) > 0 then
                        mean_sq := sum_sq_g / (WINDOW_SIZE - 1);
                    else
                        mean_sq := 0;
                    end if;
                    if mean_sq < 0 then
                        mean_sq := 0;
                    end if;

                    rmssd_expected := integer( integer(sqrt(real(mean_sq))) );


                    if rmssd_expected < 0 then
                        rmssd_expected := 0;
                    elsif rmssd_expected > (2**RMSSD_WIDTH - 1) then
                        rmssd_expected := 2**RMSSD_WIDTH - 1;
                    end if;

                    sum_sq_g     := 0;
                    diff_count_g := 0;

                    expect_valid := true;
                else
                    expect_valid := false;
                end if;
            else

                expect_valid := false;
            end if;

            prev_rr_g      := rr_curr;
            have_prev_rr_g := true;


            wait until rising_edge(aclk);

            if expect_valid then

                assert m_axis_tvalid = '1'
                    report "Expected m_axis_tvalid='1' at sample index " & integer'image(i)
                    severity error;

                got_rmssd := to_integer(unsigned(m_axis_tdata));

                assert got_rmssd = rmssd_expected
                    report "RMSSD mismatch at sample index " & integer'image(i) &
                           ". Expected=" & integer'image(rmssd_expected) &
                           " Got="      & integer'image(got_rmssd)
                    severity error;

                report "RMSSD OK at sample index " & integer'image(i) &
                       " : RMSSD = " & integer'image(got_rmssd)
                    severity note;
            else

                assert (m_axis_tvalid = '0')
                    report "Unexpected m_axis_tvalid='1' when no RMSSD expected (sample index " &
                           integer'image(i) & ")"
                    severity error;
            end if;

        end loop;

        report "All RR samples applied, tb_axis_rmssd finished." severity note;
        wait;
    end process;

end Behavioral;
