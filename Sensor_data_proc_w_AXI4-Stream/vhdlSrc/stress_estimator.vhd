library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity stress_estimator is
    generic (
        BPM_WIDTH : integer := 16;
        HRV_WIDTH : integer := 16;
        -- Thresholds (example values, tune as needed)
        BPM_MED   : integer := 80;
        BPM_HIGH  : integer := 90;
        HRV_LOW   : integer := 20;  -- low HRV (RMSSD) -> higher stress
        HRV_MED   : integer := 30
    );
    port (
        bpm_avg      : in  std_logic_vector(BPM_WIDTH-1 downto 0); -- averaged BPM
        hrv_rmssd    : in  std_logic_vector(HRV_WIDTH-1 downto 0); -- RMSSD
        stress_level : out std_logic_vector(1 downto 0)            -- 00=low, 01=mild, 10=med, 11=high
    );
end stress_estimator;

architecture Behavioral of stress_estimator is
begin
    process(bpm_avg, hrv_rmssd)
        variable bpm_i : integer;
        variable hrv_i : integer;
        variable lvl   : std_logic_vector(1 downto 0);
    begin
        bpm_i := to_integer(unsigned(bpm_avg));
        hrv_i := to_integer(unsigned(hrv_rmssd));

        -- Default: low stress
        lvl := "00";

        -- Simple heuristic:
        -- high BPM + low HRV -> high stress
        if (bpm_i >= BPM_HIGH) and (hrv_i <= HRV_LOW) then
            lvl := "11";  -- high stress
        elsif (bpm_i >= BPM_MED) and (hrv_i <= HRV_MED) then
            lvl := "10";  -- medium stress
        elsif (bpm_i >= BPM_MED) or (hrv_i <= HRV_MED) then
            lvl := "01";  -- mild stress
        else
            lvl := "00";  -- low stress
        end if;

        stress_level <= lvl;
    end process;
end Behavioral;
