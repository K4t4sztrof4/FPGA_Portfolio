library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.common_pkg.all;

entity ssd_controller is
    Port (
        clk          : in  std_logic;
        rst          : in  std_logic;
        mode         : in  std_logic_vector(3 downto 0);

        digits_mode0 : in  std_logic_vector(15 downto 0); --hr
        digits_mode1 : in  std_logic_vector(15 downto 0); --average hr
        digits_mode2 : in  std_logic_vector(15 downto 0); --hrv
        digits_mode3 : in  std_logic_vector(15 downto 0); --stress
        digits_mode4 : in  std_logic_vector(15 downto 0); --raw ir
        digits_mode5 : in  std_logic_vector(15 downto 0); --max hr
        digits_mode6 : in  std_logic_vector(15 downto 0); --min hr
        
        valid0 : in  std_logic; --hr
        valid1 : in  std_logic; --avg hr
        valid2 : in  std_logic; --hrv
        valid3 : in  std_logic; --stress
        valid4 : in  std_logic; --raw ir
        valid5 : in  std_logic; --min hr
        valid6 : in  std_logic; --max hr
        
        digits_out   : out std_logic_vector(19 downto 0)
    );
end ssd_controller;

architecture Behavioral of ssd_controller is

    --animation state + show state
    type state_t is (ANIM, SHOW);
    signal state_reg, state_next : state_t;

    signal curr_mode_reg, curr_mode_next : std_logic_vector(3 downto 0);
    -- Animation timer: 0.5 s at 100 MHz
    -- 0.5 s * 100e6 =  50,000,000 cycles
    -- 1.0 s * 100e6 = 100,000,000 cycles
    constant ANIM_TICKS : unsigned(26 downto 0) := to_unsigned(C_ANIMATION_DURATION - 1, 27);
    signal   anim_counter : unsigned(26 downto 0) := (others => '0');
    signal   anim_done    : std_logic;

begin

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state_reg     <= ANIM; -- show animation at startup
                curr_mode_reg <= "0000";
            else
                state_reg     <= state_next;
                curr_mode_reg <= curr_mode_next;
            end if;
        end if;
    end process;

    -- animation timer: counts only in ANIM
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
                    anim_counter <= (others => '0');
                end if;
            end if;
        end if;
    end process;

    anim_done <= '1' when (state_reg = ANIM and anim_counter = ANIM_TICKS)
                 else '0';

    --next-state+mode logic
    process(state_reg, mode, curr_mode_reg, anim_done)
    begin
        state_next     <= state_reg;
        curr_mode_next <= curr_mode_reg;

        case state_reg is

            when ANIM =>
                curr_mode_next <= mode;

                if anim_done = '1' then
                    state_next <= SHOW;
                end if;

            -- normal display; if mode changes, go back to ANIM
            when SHOW =>
                if mode /= curr_mode_reg then
                    -- new mode selected -> start animation for that mode
                    state_next     <= ANIM;
                    curr_mode_next <= mode;
                end if;

        end case;
    end process;

    -- output logic: animation frame or selected mode digits
    process(state_reg, curr_mode_reg,
            digits_mode0, digits_mode1, digits_mode2, digits_mode3)
    begin
        digits_out <= (others => '0');

        case state_reg is

            when ANIM =>
                case curr_mode_reg is
                    when "0000"   => digits_out <= CH_H & CH_R & CH_BLANK & CH_BLANK;   --Hr (blank)(blank)
                    when "0001"   => digits_out <= CH_A & CH_UNDERSCORE & CH_H & CH_R;  --A_Hr
                    when "0010"   => digits_out <= CH_H & CH_R & CH_U & CH_UNDERSCORE;  --hrv_
                    when "0011"   => digits_out <= CH_S & CH_T & CH_R & CH_S;           --Stress
                    when "0100"   => digits_out <= CH_R & CH_UNDERSCORE & CH_I & CH_R;  --r_ir
                    when "0101"   => digits_out <= CH_N & CH_N & CH_A & CH_H;           --MAX
                    when "0110"   => digits_out <= CH_N & CH_N & CH_I & CH_N;           --MIN
                    --when data is still processed
--                    when "0111"   => digits_out <= CH_H & CH_R & CH_BLANK & CH_BLANK;   --Hr (blank)(blank) + proc
--                    when "1000"   => digits_out <= CH_A & CH_UNDERSCORE & CH_H & CH_R;  --A_Hr + proc
--                    when "1001"   => digits_out <= CH_H & CH_R & CH_U & CH_UNDERSCORE;  --hrv_ + proc
--                    when "1010"   => digits_out <= CH_S & CH_T & CH_R & CH_S;           --Stress + proc
--                    when "1011"   => digits_out <= CH_R & CH_UNDERSCORE & CH_I & CH_R;  --r_ir + proc
--                    when "1100"   => digits_out <= CH_N & CH_N & CH_A & CH_H;           --MAX + proc
--                    when "1101"   => digits_out <= CH_N & CH_N & CH_I & CH_N;           --MIN + proc
                    when others   => digits_out <= CH_E & CH_R & CH_R & CH_BLANK;       --ERR
                end case;

            when SHOW =>
                --now output data from the corresponding mode
                case curr_mode_reg is
                    when "0000"   => 
                                    if valid0 = '1' then
                                        digits_out <= '0' & digits_mode0(15 downto 12) & '0' & digits_mode0(11 downto 8) & '0' & digits_mode0(7 downto 4) & '0' & digits_mode0(3 downto 0);
                                    end if;
                    when "0001"   => 
                                    if valid1 = '1' then 
                                        digits_out <= '0' & digits_mode1(15 downto 12) & '0' & digits_mode1(11 downto 8) & '0' & digits_mode1(7 downto 4) & '0' & digits_mode1(3 downto 0);
                                    else
                                        digits_out <= CH_p & CH_R & CH_o & CH_c;
                                    end if;
                    when "0010"   =>  
                                    if valid2 = '1' then
                                        digits_out <= '0' & digits_mode2(15 downto 12) & '0' & digits_mode2(11 downto 8) & '0' & digits_mode2(7 downto 4) & '0' & digits_mode2(3 downto 0);
                                    else 
                                        digits_out <= CH_p & CH_R & CH_o & CH_c;
                                    end if;
                    when "0011"   =>  
                                    if valid3 = '1' then
                                        digits_out <= '0' & digits_mode3(15 downto 12) & '0' & digits_mode3(11 downto 8) & '0' & digits_mode3(7 downto 4) & '0' & digits_mode3(3 downto 0);
                                    else 
                                        digits_out <= CH_p & CH_R & CH_o & CH_c;
                                    end if;
                    when "0100"   =>  --note that there is no else!
                                    if valid4 = '1' then
                                        digits_out <= '0' & digits_mode4(15 downto 12) & '0' & digits_mode4(11 downto 8) & '0' & digits_mode4(7 downto 4) & '0' & digits_mode4(3 downto 0);
                                    end if;
                    when "0101"   =>  
                                    if valid5 = '1' then
                                        digits_out <= '0' & digits_mode5(15 downto 12) & '0' & digits_mode5(11 downto 8) & '0' & digits_mode5(7 downto 4) & '0' & digits_mode5(3 downto 0);
                                    else 
                                        digits_out <= CH_p & CH_R & CH_o & CH_c;
                                    end if;
                    when "0110"   =>  
                                    if valid6 = '1' then
                                        digits_out <= '0' & digits_mode6(15 downto 12) & '0' & digits_mode6(11 downto 8) & '0' & digits_mode6(7 downto 4) & '0' & digits_mode6(3 downto 0);
                                    else 
                                        digits_out <= CH_p & CH_R & CH_o & CH_c;
                                    end if;
                    
--                    when "0111"   => digits_out <= CH_p & CH_R & CH_o & CH_c;  --Hr (blank)(blank) + proc
--                    when "1000"   => digits_out <= CH_p & CH_R & CH_o & CH_c;  --A_Hr + proc
--                    when "1001"   => digits_out <= CH_p & CH_R & CH_o & CH_c;  --hrv_ + proc
--                    when "1010"   => digits_out <= CH_p & CH_R & CH_o & CH_c;  --Stress + proc
--                    when "1011"   => digits_out <= CH_p & CH_R & CH_o & CH_c;  --r_ir + proc
--                    when "1100"   => digits_out <= CH_p & CH_R & CH_o & CH_c;  --MAX + proc
--                    when "1101"   => digits_out <= CH_p & CH_R & CH_o & CH_c;  --MIN + proc
                    
                    when others   => digits_out <= CH_E & CH_R & CH_R & CH_BLANK;
                end case;

        end case;
    end process;

end Behavioral;
