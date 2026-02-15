library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ssd_control_slow_display is
    Port (
        clk          : in  std_logic;
        rst          : in  std_logic;
        mode         : in  std_logic_vector(3 downto 0);  -- "0000".."1111"

        -- 4 digits (BCD nibbles) per mode: [15:12]=digit3 ... [3:0]=digit0
        digits_mode0 : in  std_logic_vector(15 downto 0); -- hr
        digits_mode1 : in  std_logic_vector(15 downto 0); -- average hr
        digits_mode2 : in  std_logic_vector(15 downto 0); -- hrv
        digits_mode3 : in  std_logic_vector(15 downto 0); -- stress
        digits_mode4 : in  std_logic_vector(15 downto 0); -- raw ir
        digits_mode5 : in  std_logic_vector(15 downto 0); -- max hr
        digits_mode6 : in  std_logic_vector(15 downto 0); -- min hr
        
        valid0 : in  std_logic; -- hr
        valid1 : in  std_logic; -- avg hr
        valid2 : in  std_logic; -- hrv
        valid3 : in  std_logic; -- stress
        valid4 : in  std_logic; -- raw ir
        valid5 : in  std_logic; -- max hr
        valid6 : in  std_logic; -- min hr
        
        -- Selected digits that go to your 7-seg driver
        digits_out   : out std_logic_vector(19 downto 0)
    );
end ssd_control_slow_display;

architecture Behavioral of ssd_control_slow_display is

    --------------------------------------------------------------------------
    -- FSM: one animation state + one show state
    --------------------------------------------------------------------------
    type state_t is (ANIM, SHOW);
    signal state_reg, state_next : state_t;

    -- Mode currently being displayed
    signal curr_mode_reg, curr_mode_next : std_logic_vector(3 downto 0);

    --------------------------------------------------------------------------
    -- Animation timer (you had 0.5 s in comment, but constant is 5_000_000)
    -- Adjust as you like; keeping your value.
    --------------------------------------------------------------------------
    constant ANIM_TICKS : unsigned(26 downto 0) := to_unsigned(100_000_000 - 1, 27);
    signal   anim_counter : unsigned(26 downto 0) := (others => '0');
    signal   anim_done    : std_logic;
    
    --------------------------------------------------------------------------
    -- SHOW hold timer: 0.5 s at 100 MHz = 50,000,000 cycles
    --------------------------------------------------------------------------
    constant SHOW_TICKS   : unsigned(25 downto 0) := to_unsigned(50_000_000 - 1, 26);
    signal   show_counter : unsigned(25 downto 0) := (others => '0');

    -- Instantaneous values (combinational)
    signal anim_digits : std_logic_vector(19 downto 0) := (others => '0');
    signal show_digits : std_logic_vector(19 downto 0) := (others => '0');

    -- Held SHOW value that actually drives the display in SHOW
    signal show_hold   : std_logic_vector(19 downto 0) := (others => '0');
    
    --------------------------------------------------------------------------
    -- Character codes (5 bits each, 4 chars -> 20 bits)
    --------------------------------------------------------------------------
    constant CH_BLANK       : std_logic_vector(4 downto 0) := "11011";
    constant CH_UNDERSCORE  : std_logic_vector(4 downto 0) := "10010"; 
    constant CH_A           : std_logic_vector(4 downto 0) := "01010";
    constant CH_U           : std_logic_vector(4 downto 0) := "10100";
    constant CH_H           : std_logic_vector(4 downto 0) := "10000";
    constant CH_R           : std_logic_vector(4 downto 0) := "10001";
    constant CH_E           : std_logic_vector(4 downto 0) := "01110";
    constant CH_S           : std_logic_vector(4 downto 0) := "00101";
    constant CH_T           : std_logic_vector(4 downto 0) := "10101";
    constant CH_I           : std_logic_vector(4 downto 0) := "10011";
    constant CH_P           : std_logic_vector(4 downto 0) := "11000";
    constant CH_o           : std_logic_vector(4 downto 0) := "11001";
    constant CH_c           : std_logic_vector(4 downto 0) := "11010";
    constant CH_N           : std_logic_vector(4 downto 0) := "11100";

begin

    --------------------------------------------------------------------------
    -- State + mode registers
    --------------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state_reg     <= ANIM;      -- show animation at startup
                curr_mode_reg <= "0000";    -- default mode
            else
                state_reg     <= state_next;
                curr_mode_reg <= curr_mode_next;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------------
    -- Animation timer: counts only in ANIM
    --------------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                anim_counter <= (others => '0');
            else
                if state_reg = ANIM then
                    if anim_counter = ANIM_TICKS then
                        anim_counter <= (others => '0');
                    else
                        anim_counter <= anim_counter + 1;
                    end if;
                else
                    anim_counter <= (others => '0');  -- reset when not animating
                end if;
            end if;
        end if;
    end process;

    anim_done <= '1' when (state_reg = ANIM and anim_counter = ANIM_TICKS)
                 else '0';

    --------------------------------------------------------------------------
    -- Next-state and next-mode logic
    --------------------------------------------------------------------------
    process(state_reg, mode, curr_mode_reg, anim_done)
    begin
        state_next     <= state_reg;
        curr_mode_next <= curr_mode_reg;

        case state_reg is

            -- Show one-frame animation, then go to SHOW with current mode
            when ANIM =>
                -- always track the latest mode during animation
                curr_mode_next <= mode;

                if anim_done = '1' then
                    state_next <= SHOW;
                end if;

            -- Normal display; if mode changes, go back to ANIM
            when SHOW =>
                if mode /= curr_mode_reg then
                    -- new mode selected -> start animation for that mode
                    state_next     <= ANIM;
                    curr_mode_next <= mode;
                end if;

        end case;
    end process;

    --------------------------------------------------------------------------
    -- Combinational: "instant" values for ANIM and SHOW
    --------------------------------------------------------------------------
    process(state_reg, curr_mode_reg,
            digits_mode0, digits_mode1, digits_mode2, digits_mode3,
            digits_mode4, digits_mode5, digits_mode6,
            valid0, valid1, valid2, valid3, valid4, valid5, valid6)
    begin
        anim_digits <= (others => '0');
        show_digits <= (others => '0');

        case state_reg is

            ------------------------------------------------------------------
            -- ANIMATION: text / labels
            ------------------------------------------------------------------
            when ANIM =>
                case curr_mode_reg is
                    when "0000"   => anim_digits <= CH_H & CH_R & CH_BLANK & CH_BLANK;   -- Hr__
                    when "0001"   => anim_digits <= CH_A & CH_UNDERSCORE & CH_H & CH_R;  -- A_Hr
                    when "0010"   => anim_digits <= CH_H & CH_R & CH_U & CH_UNDERSCORE;  -- hrv_
                    when "0011"   => anim_digits <= CH_S & CH_T & CH_R & CH_S;           -- Stress
                    when "0100"   => anim_digits <= CH_R & CH_UNDERSCORE & CH_I & CH_R;  -- r_ir
                    when "0101"   => anim_digits <= CH_N & CH_N & CH_A & CH_H;           -- MAX
                    when "0110"   => anim_digits <= CH_N & CH_N & CH_I & CH_N;           -- MIN
                    when others   => anim_digits <= CH_E & CH_R & CH_R & CH_BLANK;       -- ERR
                end case;

            ------------------------------------------------------------------
            -- SHOW: numeric / PROC / ERR text (instantaneous)
            ------------------------------------------------------------------
            when SHOW =>
                case curr_mode_reg is
                    when "0000"   =>
                        if valid0 = '1' then
                            show_digits <= '0' & digits_mode0(15 downto 12) &
                                           '0' & digits_mode0(11 downto 8)  &
                                           '0' & digits_mode0(7  downto 4)  &
                                           '0' & digits_mode0(3  downto 0);
                        end if;

                    when "0001"   =>
                        if valid1 = '1' then
                            show_digits <= '0' & digits_mode1(15 downto 12) &
                                           '0' & digits_mode1(11 downto 8)  &
                                           '0' & digits_mode1(7  downto 4)  &
                                           '0' & digits_mode1(3  downto 0);
                        else
                            show_digits <= CH_P & CH_R & CH_o & CH_c;  -- PROC
                        end if;

                    when "0010"   =>
                        if valid2 = '1' then
                            show_digits <= '0' & digits_mode2(15 downto 12) &
                                           '0' & digits_mode2(11 downto 8)  &
                                           '0' & digits_mode2(7  downto 4)  &
                                           '0' & digits_mode2(3  downto 0);
                        else
                            show_digits <= CH_P & CH_R & CH_o & CH_c;
                        end if;

                    when "0011"   =>
                        if valid3 = '1' then
                            show_digits <= '0' & digits_mode3(15 downto 12) &
                                           '0' & digits_mode3(11 downto 8)  &
                                           '0' & digits_mode3(7  downto 4)  &
                                           '0' & digits_mode3(3  downto 0);
                        else
                            show_digits <= CH_P & CH_R & CH_o & CH_c;
                        end if;

                    when "0100"   =>
                        if valid4 = '1' then
                            show_digits <= '0' & digits_mode4(15 downto 12) &
                                           '0' & digits_mode4(11 downto 8)  &
                                           '0' & digits_mode4(7  downto 4)  &
                                           '0' & digits_mode4(3  downto 0);
                        end if;

                    when "0101"   =>
                        if valid5 = '1' then
                            show_digits <= '0' & digits_mode5(15 downto 12) &
                                           '0' & digits_mode5(11 downto 8)  &
                                           '0' & digits_mode5(7  downto 4)  &
                                           '0' & digits_mode5(3  downto 0);
                        else
                            show_digits <= CH_P & CH_R & CH_o & CH_c;
                        end if;

                    when "0110"   =>
                        if valid6 = '1' then
                            show_digits <= '0' & digits_mode6(15 downto 12) &
                                           '0' & digits_mode6(11 downto 8)  &
                                           '0' & digits_mode6(7  downto 4)  &
                                           '0' & digits_mode6(3  downto 0);
                        else
                            show_digits <= CH_P & CH_R & CH_o & CH_c;
                        end if;

                    when others   =>
                        show_digits <= CH_E & CH_R & CH_R & CH_BLANK;
                end case;

            when others =>
                anim_digits <= CH_E & CH_R & CH_R & CH_BLANK;
                show_digits <= CH_E & CH_R & CH_R & CH_BLANK;

        end case;
    end process;

    --------------------------------------------------------------------------
    -- SHOW sample-and-hold: each displayed value stays for at least 0.5 s
    -- This logic is ONLY active in SHOW state.
    --------------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                show_counter <= SHOW_TICKS;   -- so first SHOW latches immediately
                show_hold    <= (others => '0');
            else
                if state_reg = SHOW then
                    -- When counter reaches SHOW_TICKS, latch current show_digits
                    if show_counter = SHOW_TICKS then
                        show_hold    <= show_digits;
                        show_counter <= (others => '0');
                    else
                        show_counter <= show_counter + 1;
                    end if;
                else
                    -- Not in SHOW: preload counter so that entering SHOW causes
                    -- an immediate latch of the current show_digits.
                    show_counter <= SHOW_TICKS;
                    -- show_hold is kept; ANIM will not use it.
                end if;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------------
    -- Final output: no hold in ANIM, 0.5 s hold only in SHOW
    --------------------------------------------------------------------------
    with state_reg select
        digits_out <= anim_digits when ANIM,
                      show_hold   when SHOW,
                      (others => '0') when others;

end Behavioral;
