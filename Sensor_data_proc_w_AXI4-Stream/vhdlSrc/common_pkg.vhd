library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package common_pkg is

    constant C_SAMPLE_RATE  : integer :=                    100;
    constant C_DATA_WIDTH   : integer :=                    16;
    constant C_IR_MIN       : integer :=                    1000;
    constant C_IR_MAX       : integer :=                    8191;
    constant C_CLK_FREQ     : integer :=                    100_000_000;   --100 MHz
    constant C_BAUD_RATE    : integer :=                    115_200;        -- match Serial1.begin(...)
    constant C_ANIMATION_DURATION : integer :=              100_000_000; --1 second
    
    constant C_AXIS_DATA_WIDTH : integer :=                 16;
    
    constant C_AXIS_MOV_AVG_WINDOW_SIZE : integer :=        32; --MIST BE POWER OF TWO
    constant C_AXIS_MOV_AVG_SUM_WIDTH : integer :=          22;  -- enough bits for sum
    constant C_AXIS_MOV_AVG_SHIFT_BITS : integer :=         5;  -- LOG2(C_AXIS_MOV_AVG_WINDOW_SIZE)
    
    constant C_AXIS_PEAK_DET_THRESHOLD : integer :=         1000; --100 volt
    
    constant C_AXIS_RR_INTERVAL_COUNTER_WIDTH : integer :=  16;
    constant C_AXIS_RR_INTERVAL_RR_WIDTH : integer :=       16;
    constant C_AXIS_RR_INTERVAL_RR_MIN : integer :=         80;
    
    constant C_AXIS_BPM_WIDTH : integer :=                  16;
    constant C_AXIS_AVG_BPM_WINDOW_SIZE: integer :=         16;
    constant C_AXIS_RMSSD_WINDOW_SIZE: integer :=           16;
    constant C_AXIS_RMSSD_WIDTH: integer :=                 16;
    
    constant C_BPM_MEDIUM: integer :=   70;
    constant C_BPM_HIGH: integer :=     90;
    constant C_HRV_LOW: integer :=      30;
    constant C_HRV_MEDIUM: integer :=   40;
    
    
    
    --characters for ssd_display
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
end package;

package body common_pkg is


end package body;
