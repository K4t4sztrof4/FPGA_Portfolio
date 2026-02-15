library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_stress_estimator is
end tb_stress_estimator;

architecture Behavioral of tb_stress_estimator is

    --------------------------------------------------------------------
    -- Match DUT generics
    --------------------------------------------------------------------
    constant BPM_WIDTH : integer := 16;
    constant HRV_WIDTH : integer := 16;

    -- Same thresholds as DUT (can be overridden if you change generics)
    constant BPM_MED   : integer := 80;
    constant BPM_HIGH  : integer := 90;
    constant HRV_LOW   : integer := 20;
    constant HRV_MED   : integer := 30;

    --------------------------------------------------------------------
    -- DUT ports
    --------------------------------------------------------------------
    signal bpm_avg      : std_logic_vector(BPM_WIDTH-1 downto 0) := (others => '0');
    signal hrv_rmssd    : std_logic_vector(HRV_WIDTH-1 downto 0) := (others => '0');
    signal stress_level : std_logic_vector(1 downto 0);

    --------------------------------------------------------------------
    -- Test vectors
    -- Each case: (BPM, HRV) -> expected stress_level
    -- 00 = low, 01 = mild, 10 = medium, 11 = high
    --------------------------------------------------------------------
    type int_array is array (natural range <>) of integer;
    type slv2_array is array (natural range <>) of std_logic_vector(1 downto 0);

    constant NUM_TESTS : integer := 8;

    constant test_bpm : int_array(0 to NUM_TESTS-1) :=
    --  idx : desc
        ( 70,   -- 0: BPM < MED, HRV high -> low
          85,   -- 1: BPM between MED & HIGH, HRV high -> mild
          95,   -- 2: BPM >= HIGH, HRV high -> mild (no HRV penalty)
          85,   -- 3: BPM between MED & HIGH, HRV <= MED -> medium
          95,   -- 4: BPM >= HIGH, HRV <= LOW -> high
          60,   -- 5: BPM low, HRV <= MED -> mild
          60,   -- 6: BPM low, HRV very low -> mild (no high/med since BPM < MED)
          90    -- 7: BPM = HIGH, HRV just above LOW but <= MED -> medium
        );

    constant test_hrv : int_array(0 to NUM_TESTS-1) :=
        ( 40,   -- 0: HRV > MED
          40,   -- 1: HRV > MED
          40,   -- 2: HRV > MED
          25,   -- 3: HRV <= MED
          10,   -- 4: HRV <= LOW
          25,   -- 5: HRV <= MED
          15,   -- 6: HRV <= LOW (but BPM low)
          25    -- 7: HRV <= MED, > LOW
        );

    constant expected_level : slv2_array(0 to NUM_TESTS-1) :=
        ( "00",   -- 0: low
          "01",   -- 1: mild
          "01",   -- 2: mild
          "10",   -- 3: medium
          "11",   -- 4: high
          "01",   -- 5: mild
          "01",   -- 6: mild
          "10"    -- 7: medium
        );

begin

    --------------------------------------------------------------------
    -- DUT instantiation
    --------------------------------------------------------------------
    uut : entity work.stress_estimator
        generic map (
            BPM_WIDTH => BPM_WIDTH,
            HRV_WIDTH => HRV_WIDTH,
            BPM_MED   => BPM_MED,
            BPM_HIGH  => BPM_HIGH,
            HRV_LOW   => HRV_LOW,
            HRV_MED   => HRV_MED
        )
        port map (
            bpm_avg      => bpm_avg,
            hrv_rmssd    => hrv_rmssd,
            stress_level => stress_level
        );

    --------------------------------------------------------------------
    -- Stimulus process
    --------------------------------------------------------------------
    stim_proc : process
        variable i : integer;
    begin
        for i in 0 to NUM_TESTS-1 loop
            -- Apply inputs
            bpm_avg   <= std_logic_vector(to_unsigned(test_bpm(i), BPM_WIDTH));
            hrv_rmssd <= std_logic_vector(to_unsigned(test_hrv(i), HRV_WIDTH));

            -- Wait some delta time for combinational logic to settle
            wait for 10 ns;

            -- Check result
            assert stress_level = expected_level(i)
                report "Stress level mismatch for test " & integer'image(i) &
                       ". BPM=" & integer'image(test_bpm(i)) &
                       " HRV=" & integer'image(test_hrv(i)) &
                       " Expected=" & std_logic'image(expected_level(i)(1)) &
                                     std_logic'image(expected_level(i)(0)) &
                       " Got="      & std_logic'image(stress_level(1)) &
                                     std_logic'image(stress_level(0))
                severity error;

            report "Test " & integer'image(i) &
                   " OK: BPM=" & integer'image(test_bpm(i)) &
                   " HRV=" & integer'image(test_hrv(i)) &
                   " -> stress_level=" &
                   std_logic'image(stress_level(1)) &
                   std_logic'image(stress_level(0))
                severity note;

        end loop;

        report "All stress_estimator tests completed successfully." severity note;
        wait;
    end process;

end Behavioral;
