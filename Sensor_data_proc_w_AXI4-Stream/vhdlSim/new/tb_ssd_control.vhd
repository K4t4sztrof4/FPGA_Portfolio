library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_ssd_control is
end tb_ssd_control;

architecture sim of tb_ssd_control is

    -----------------------------------------------------------------------
    -- Clock period: 100 MHz => 10 ns
    -----------------------------------------------------------------------
    constant CLK_PERIOD : time := 10 ns;

    -- DUT signals
    signal clk        : std_logic := '0';
    signal rst        : std_logic := '1';
    signal mode       : std_logic_vector(3 downto 0) := (others => '0');

    signal digits_mode0 : std_logic_vector(15 downto 0) := (others => '0');
    signal digits_mode1 : std_logic_vector(15 downto 0) := (others => '0');
    signal digits_mode2 : std_logic_vector(15 downto 0) := (others => '0');
    signal digits_mode3 : std_logic_vector(15 downto 0) := (others => '0');
    signal digits_mode4 : std_logic_vector(15 downto 0) := (others => '0');
    signal digits_mode5 : std_logic_vector(15 downto 0) := (others => '0');
    signal digits_mode6 : std_logic_vector(15 downto 0) := (others => '0');

    signal valid0 : std_logic := '0';
    signal valid1 : std_logic := '0';
    signal valid2 : std_logic := '0';
    signal valid3 : std_logic := '0';
    signal valid4 : std_logic := '0';
    signal valid5 : std_logic := '0';
    signal valid6 : std_logic := '0';

    signal digits_out : std_logic_vector(19 downto 0);

begin

    -----------------------------------------------------------------------
    -- Clock generation (100 MHz)
    -----------------------------------------------------------------------
    clk_process : process
    begin
        clk <= '0';
        wait for CLK_PERIOD / 2;
        clk <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    -----------------------------------------------------------------------
    -- DUT instantiation
    -----------------------------------------------------------------------
    uut : entity work.ssd_controller
        port map (
            clk          => clk,
            rst          => rst,
            mode         => mode,

            digits_mode0 => digits_mode0,
            digits_mode1 => digits_mode1,
            digits_mode2 => digits_mode2,
            digits_mode3 => digits_mode3,
            digits_mode4 => digits_mode4,
            digits_mode5 => digits_mode5,
            digits_mode6 => digits_mode6,

            valid0       => valid0,
            valid1       => valid1,
            valid2       => valid2,
            valid3       => valid3,
            valid4       => valid4,
            valid5       => valid5,
            valid6       => valid6,

            digits_out   => digits_out
        );

    -----------------------------------------------------------------------
    -- Stimulus
    -----------------------------------------------------------------------
    stim_proc : process
        variable expected : std_logic_vector(19 downto 0);
    begin
        -------------------------------------------------------------------
        -- Initial reset and input setup
        -------------------------------------------------------------------
        -- Choose a recognizable pattern for mode 0, e.g. 1-2-3-4
        digits_mode0 <= x"1234";
        valid0       <= '1';

        -- other modes not used in this simple test
        digits_mode1 <= x"0000";
        digits_mode2 <= x"0000";
        digits_mode3 <= x"0000";
        digits_mode4 <= x"0000";
        digits_mode5 <= x"0000";
        digits_mode6 <= x"0000";

        valid1 <= '0';
        valid2 <= '0';
        valid3 <= '0';
        valid4 <= '0';
        valid5 <= '0';
        valid6 <= '0';

        -- Start in mode "0000"
        mode <= "0000";

        -- Hold reset for a bit
        rst <= '1';
        wait for 100 ns;
        rst <= '0';

        -------------------------------------------------------------------
        -- Wait for the animation to complete
        --
        -- In your RTL: ANIM_TICKS = 5_000_000 - 1
        -- At 100 MHz => 5_000_000 cycles * 10 ns = 50 ms
        -- We wait a bit more (60 ms) to be safe.
        -------------------------------------------------------------------
        wait for 60 ms;

        -------------------------------------------------------------------
        -- Now the FSM should be in SHOW state for mode "0000"
        -- digits_out should show digits_mode0 with '0' prefixed to each nibble:
        -- '0' & [15:12] & '0' & [11:8] & '0' & [7:4] & '0' & [3:0]
        -------------------------------------------------------------------
        expected := '0' & digits_mode0(15 downto 12) &
                    '0' & digits_mode0(11 downto 8)  &
                    '0' & digits_mode0(7  downto 4)  &
                    '0' & digits_mode0(3  downto 0);

        -- Give it a couple of clock cycles to settle after the FSM transition
        wait for 5 * CLK_PERIOD;

        assert digits_out = expected
            report "digits_out mismatch after animation finished (mode 0000 SHOW state)."
            severity error;

        report "Test completed successfully. digits_out matches expected value after animation."
            severity note;

        wait;
    end process;

end sim;
