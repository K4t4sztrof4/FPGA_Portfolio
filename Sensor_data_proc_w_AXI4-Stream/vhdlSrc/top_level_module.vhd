library IEEE;
use IEEE.STD_LOGIC_1164.ALL;


library work;
use work.common_pkg.all;

entity top_level_module is
  Port (
        clk100    : in  std_logic;   
        JC1       : in  std_logic;   -- JC[0] used as UART RX
        rst, btnC : in  std_logic;                   
        an        : out std_logic_vector(3 downto 0);
        cat       : out std_logic_vector(6 downto 0)
   );
end top_level_module;

architecture Behavioral of top_level_module is

component debouncer is
  Port ( clk : in std_logic;
        btn : in std_logic;
        en : out std_logic );
end component;

component toggle_6way is
    Port (
        clk       : in  std_logic;
        rst       : in  std_logic;
        btn_pulse : in  std_logic;
        mode      : out std_logic_vector(3 downto 0)  -- 0000..1111
    );
end component;

component ssd_controller is
    Port (
        clk          : in  std_logic;
        rst          : in  std_logic;
        mode         : in  std_logic_vector(3 downto 0);  -- "0000".."1111"

        -- 4 digits (BCD nibbles) per mode: [15:12]=digit3 ... [3:0]=digit0
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
        
        -- Selected digits that go to your 7-seg driver
        digits_out   : out std_logic_vector(19 downto 0)
    );
end component;
component seven_segment_display is
    Port ( digit0 : in STD_LOGIC_VECTOR (4 downto 0);
           digit1 : in STD_LOGIC_VECTOR (4 downto 0);
           digit2 : in STD_LOGIC_VECTOR (4 downto 0);
           digit3 : in STD_LOGIC_VECTOR (4 downto 0);
           clk : in STD_LOGIC;
           cat : out STD_LOGIC_VECTOR (6 downto 0);
           an : out STD_LOGIC_VECTOR (3 downto 0));
end component;

component bin16_to_bcd is
  Port (
        bin_in : in std_logic_vector(15 downto 0);
        bcd_out : out std_logic_vector(15 downto 0)
  );
end component;

component uart_bit_sampler is
    generic (
        CLK_FREQ  : integer := C_CLK_FREQ;  -- 100 MHz
        BAUD_RATE : integer := C_BAUD_RATE      -- or 9600, etc.
    );
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;

        rx       : in  std_logic;           -- from JC1 pin

        data_out : out std_logic_vector(7 downto 0);
        data_ready : out std_logic           -- 1 clk pulse when a byte is received
    );
end component;
component uart_word_assembler is
    Port ( clk : in STD_LOGIC;
           rst : in STD_LOGIC;
           rx_ready : in STD_LOGIC;
           rx_byte : in STD_LOGIC_VECTOR (7 downto 0);
           word16 : out STD_LOGIC_VECTOR (15 downto 0);
           word_valid : out STD_LOGIC);
end component;

component uart_word_to_bcd is
    Port (
        clk            : in  STD_LOGIC;
        rst            : in  STD_LOGIC;

        -- from uart_word_assembler
        word16_in      : in  STD_LOGIC_VECTOR(15 downto 0);
        word_valid_in  : in  STD_LOGIC;

        -- BCD result
        bcd_out        : out STD_LOGIC_VECTOR(15 downto 0);
        bcd_valid      : out STD_LOGIC
    );
end component;

signal rst_d, btnC_d, btnL_d, btnR_d : std_logic:='0';
signal mode : std_logic_vector(3 downto 0):="1111";

signal digits_mode0: std_logic_vector(15 downto 0);
signal digits_mode1: std_logic_vector(15 downto 0);
signal digits_mode2: std_logic_vector(15 downto 0);
signal digits_mode3: std_logic_vector(15 downto 0);
signal digits_mode4: std_logic_vector(15 downto 0);
signal digits_mode5: std_logic_vector(15 downto 0);
signal digits_mode6: std_logic_vector(15 downto 0);
signal digits_out: std_logic_vector(19 downto 0):=(others => '0');
signal an_inter: std_logic_vector(3 downto 0):=(others => '0');
signal cat_inter: std_logic_vector(6 downto 0):=(others => '0');
signal v0, v1, v2, v3, v4, v5, v6 : std_logic := '0';
signal v0_flag, v1_flag, v2_flag, v3_flag, v4_flag, v5_flag, v6_flag : boolean := false;
------------------------
--uart_bit_sampler
-----------------------

signal rx_byte, rx_byte_dup                  : std_logic_vector(7 downto 0);
signal rx_ready_inter, rx_ready_inter_dup    : std_logic;
signal rx_value                              : std_logic_vector(7 downto 0);
signal rx_digits                             : std_logic_vector(15 downto 0);

signal word16    : std_logic_vector(15 downto 0);
signal word_valid, rx_valid : std_logic := '0';

----------------------
--AXIS inter signals
----------------------
signal axis_u2s_tdata, axis_u2s_tdata_dup, axis_sat_tdata, axis_sat_tdata_dup, axis_filt_tdata, axis_filt_tdata_dup, axis_peak_tdata, axis_peak_tdata_dup, axis_rr_tdata, axis_rr_tdata_dup, axis_rr_to_bpm_tdata, axis_rr_to_hrv_tdata, axis_bpm_tdata : std_logic_vector(15 downto 0);
signal axis_u2s_tvalid, axis_u2s_tvalid_dup, axis_sat_tvalid, axis_sat_tvalid_dup, axis_filt_tvalid, axis_filt_tvalid_dup, axis_peak_tvalid, axis_peak_tvalid_dup, axis_rr_tvalid, axis_rr_tvalid_dup, axis_rr_to_bpm_tvalid, axis_rr_to_hrv_tvalid, axis_bpm_tvalid : std_logic;
signal axis_u2s_tready, axis_u2s_tready_dup, axis_sat_tready, axis_sat_tready_dup, axis_filt_tready, axis_filt_tready_dup, axis_peak_tready, axis_peak_tready_dup, axis_rr_tready, axis_rr_tready_dup, axis_rr_to_bpm_tready, axis_rr_to_hrv_tready : std_logic; 
signal axis_peak_flag, axis_peak_flag_dup : std_logic; 
signal axis_bpm_tready : std_logic := '1'; 
signal instant_bpm_valid, average_bpm_valid, hrv_valid, strs_tvalid, stress_valid : std_logic:='0';

-- Averaged BPM (from axis_bpm_avg)
signal bpm_avg_tdata, axis_rmssd_tdata   : std_logic_vector(15 downto 0);
signal bpm_avg_tvalid, axis_rmssd_tvalid  : std_logic;
signal bpm_avg_tready, axis_rmssd_tready  : std_logic := '1';  

signal stress_level_sig             : std_logic_vector(1 downto 0);
signal stress_sig, max_sig, min_sig : std_logic_vector(15 downto 0);
signal max_valid, min_valid, max_valid_fin, min_valid_fin : std_logic;
begin

btnU_debouncer: debouncer   port map (clk100, rst, rst_d); --rst
btnC_debouncer: debouncer   port map (clk100, btnC, btnC_d); --toggle

toggle:         toggle_6way port map (clk100, rst_d, btnC_d, mode);
displ_c:        ssd_controller port map (clk100, rst_d, mode, digits_mode0, digits_mode1, digits_mode2, digits_mode3, digits_mode4, digits_mode5, digits_mode6, v0, v1, v2, v3, v4, v5, v6, digits_out);
display:        seven_segment_display         port map (digits_out(4 downto 0),digits_out(9 downto 5),digits_out(14 downto 10),digits_out(19 downto 15), clk100, cat_inter, an_inter);

rx_layer0: uart_bit_sampler generic map (C_CLK_FREQ, C_BAUD_RATE) port map(
clk => clk100, 
rst => rst_d, 
rx => JC1, 
data_out => rx_byte, 
data_ready => rx_ready_inter);

rx_layer0_dup: uart_bit_sampler generic map (C_CLK_FREQ, C_BAUD_RATE) port map(
clk => clk100, 
rst => rst_d, 
rx => JC1, 
data_out => rx_byte_dup, 
data_ready => rx_ready_inter_dup);

uart_axis_src : entity work.uart_word_assembler_axis
    port map (
        aclk          => clk100,
        rst          => rst_d,  -- or your global AXI reset
        rx_ready     => rx_ready_inter,
        rx_byte      => rx_byte,
        m_axis_tdata => axis_u2s_tdata,
        m_axis_tvalid=> axis_u2s_tvalid,
        m_axis_tready=> axis_u2s_tready
    );
    
uart_axis_src_dup : entity work.uart_word_assembler_axis
    port map (
        aclk          => clk100,
        rst          => rst_d,  -- or your global AXI reset
        rx_ready     => rx_ready_inter_dup,
        rx_byte      => rx_byte_dup,
        m_axis_tdata => axis_u2s_tdata_dup,
        m_axis_tvalid=> axis_u2s_tvalid_dup,
        m_axis_tready=> axis_u2s_tready_dup
    );

-- Saturator
axis_sat_inst : entity work.axis_saturator
    generic map (
        DATA_WIDTH => C_DATA_WIDTH,
        MIN_VAL    => C_IR_MIN,
        MAX_VAL    => C_IR_MAX
    )
    port map (
        aclk          => clk100,
        rst           => rst_d,
        s_axis_tdata  => axis_u2s_tdata,
        s_axis_tvalid => axis_u2s_tvalid,
        s_axis_tready => axis_u2s_tready,
        m_axis_tdata  => axis_sat_tdata,
        m_axis_tvalid => axis_sat_tvalid,
        m_axis_tready => axis_sat_tready
    );
    
axis_sat_inst_dup : entity work.axis_saturator
    generic map (
        DATA_WIDTH => C_DATA_WIDTH,
        MIN_VAL    => C_IR_MIN,
        MAX_VAL    => C_IR_MAX
    )
    port map (
        aclk          => clk100,
        rst           => rst_d,
        s_axis_tdata  => axis_u2s_tdata_dup,
        s_axis_tvalid => axis_u2s_tvalid_dup,
        s_axis_tready => axis_u2s_tready_dup,
        m_axis_tdata  => axis_sat_tdata_dup,
        m_axis_tvalid => axis_sat_tvalid_dup,
        m_axis_tready => axis_sat_tready_dup
    );
-- Moving average
axis_movavg_inst : entity work.axis_moving_avg
    generic map (
        DATA_WIDTH => C_AXIS_DATA_WIDTH,
        WINDOW_SIZE=> C_AXIS_MOV_AVG_WINDOW_SIZE,
        SUM_WIDTH  => C_AXIS_MOV_AVG_SUM_WIDTH,
        SHIFT_BITS => C_AXIS_MOV_AVG_SHIFT_BITS
    )
    port map (
        aclk          => clk100,
        rst           => rst_d,
        s_axis_tdata  => axis_sat_tdata,
        s_axis_tvalid => axis_sat_tvalid,
        s_axis_tready => axis_sat_tready,
        m_axis_tdata  => axis_filt_tdata,
        m_axis_tvalid => axis_filt_tvalid,
        m_axis_tready => axis_filt_tready
    );

axis_movavg_inst_dup : entity work.axis_moving_avg
    generic map (
        DATA_WIDTH => C_AXIS_DATA_WIDTH,
        WINDOW_SIZE=> C_AXIS_MOV_AVG_WINDOW_SIZE,
        SUM_WIDTH  => C_AXIS_MOV_AVG_SUM_WIDTH,
        SHIFT_BITS => C_AXIS_MOV_AVG_SHIFT_BITS
    )
    port map (
        aclk          => clk100,
        rst           => rst_d,
        s_axis_tdata  => axis_sat_tdata_dup,
        s_axis_tvalid => axis_sat_tvalid_dup,
        s_axis_tready => axis_sat_tready_dup,
        m_axis_tdata  => axis_filt_tdata_dup,
        m_axis_tvalid => axis_filt_tvalid_dup,
        m_axis_tready => axis_filt_tready_dup
    );
    
-- Peak detector
axis_peak_inst : entity work.axis_peak_detector
    generic map (
        DATA_WIDTH => C_AXIS_DATA_WIDTH,
        THRESHOLD  => C_AXIS_PEAK_DET_THRESHOLD
    )
    port map (
        aclk             => clk100,
        rst              => rst_d,
        s_axis_tdata     => axis_filt_tdata,
        s_axis_tvalid    => axis_filt_tvalid,
        s_axis_tready    => axis_filt_tready,
        m_axis_tdata     => axis_peak_tdata,
        m_axis_tvalid    => axis_peak_tvalid,
        m_axis_tready    => axis_peak_tready,
        m_axis_tuser_peak=> axis_peak_flag
    );
    
axis_peak_inst_dup : entity work.axis_peak_detector
    generic map (
        DATA_WIDTH => C_AXIS_DATA_WIDTH,
        THRESHOLD  => C_AXIS_PEAK_DET_THRESHOLD
    )
    port map (
        aclk             => clk100,
        rst              => rst_d,
        s_axis_tdata     => axis_filt_tdata_dup,
        s_axis_tvalid    => axis_filt_tvalid_dup,
        s_axis_tready    => axis_filt_tready_dup,
        m_axis_tdata     => axis_peak_tdata_dup,
        m_axis_tvalid    => axis_peak_tvalid_dup,
        m_axis_tready    => axis_peak_tready_dup,
        m_axis_tuser_peak=> axis_peak_flag_dup
    );
    
rr_inst : entity work.axis_rr_interval
    generic map (
        COUNTER_WIDTH => C_AXIS_RR_INTERVAL_COUNTER_WIDTH,
        RR_WIDTH      => C_AXIS_RR_INTERVAL_RR_WIDTH,
        RR_MIN        => C_AXIS_RR_INTERVAL_RR_MIN   -- minimum RR in samples
    )
    port map (
        aclk            => clk100,
        rst             => rst_d,
        s_axis_tdata    => axis_peak_tdata,
        s_axis_tvalid   => axis_peak_tvalid,
        s_axis_tready   => axis_peak_tready,
        s_axis_tuser_peak => axis_peak_flag,
        m_axis_tdata    => axis_rr_tdata,
        m_axis_tvalid   => axis_rr_tvalid,
        m_axis_tready   => axis_rr_tready
    );
    
 rr_inst_dup : entity work.axis_rr_interval
    generic map (
        COUNTER_WIDTH => C_AXIS_RR_INTERVAL_COUNTER_WIDTH,
        RR_WIDTH      => C_AXIS_RR_INTERVAL_RR_WIDTH,
        RR_MIN        => C_AXIS_RR_INTERVAL_RR_MIN    -- minimum RR in samples
    )
    port map (
        aclk            => clk100,
        rst             => rst_d,
        s_axis_tdata    => axis_peak_tdata_dup,
        s_axis_tvalid   => axis_peak_tvalid_dup,
        s_axis_tready   => axis_peak_tready_dup,
        s_axis_tuser_peak => axis_peak_flag_dup,
        m_axis_tdata    => axis_rr_tdata_dup,
        m_axis_tvalid   => axis_rr_tvalid_dup,
        m_axis_tready   => axis_rr_tready_dup
    );
    
bpm_inst : entity work.axis_bpm_instant
    generic map (
        SAMPLE_RATE => C_SAMPLE_RATE,  -- set this to your real sample rate (Hz)
        BPM_WIDTH   => C_AXIS_BPM_WIDTH
    )
    port map (
        aclk           => clk100,
        rst            => rst_d,
        s_axis_tdata   => axis_rr_tdata,
        s_axis_tvalid  => axis_rr_tvalid,
        s_axis_tready  => axis_rr_tready,
        m_axis_tdata   => axis_bpm_tdata,
        m_axis_tvalid  => axis_bpm_tvalid,
        m_axis_tready  => axis_bpm_tready
    );

u_axis_bpm_avg : entity work.axis_bpm_avg
    generic map (
        BPM_WIDTH   => C_AXIS_BPM_WIDTH,
        WINDOW_SIZE => C_AXIS_AVG_BPM_WINDOW_SIZE     -- or whatever you want
    )
    port map (
        aclk          => clk100,
        rst           => rst_d,

        -- slave side: instant BPM in
        s_axis_tdata  => axis_bpm_tdata,
        s_axis_tvalid => axis_bpm_tvalid,
        s_axis_tready => axis_bpm_tready,

        -- master side: averaged BPM out
        m_axis_tdata  => bpm_avg_tdata,
        m_axis_tvalid => bpm_avg_tvalid,
        m_axis_tready => bpm_avg_tready
    );
    
u_axis_rmssd : entity work.axis_rmssd
    generic map (
        RR_WIDTH    => C_AXIS_RR_INTERVAL_RR_WIDTH,
        RMSSD_WIDTH => C_AXIS_RMSSD_WIDTH,
        WINDOW_SIZE => C_AXIS_RMSSD_WINDOW_SIZE       -- number of RR samples per HRV block
    )
    port map (
        aclk          => clk100,
        rst           => rst_d,

        -- RR input (from axis_rr_interval)
        s_axis_tdata  => axis_rr_tdata_dup,
        s_axis_tvalid => axis_rr_tvalid_dup,
        s_axis_tready => axis_rr_tready_dup,

        -- RMSSD (HRV) output
        m_axis_tdata  => axis_rmssd_tdata,
        m_axis_tvalid => axis_rmssd_tvalid,
        m_axis_tready => axis_rmssd_tready
    );

u_stress_estimator : entity work.stress_estimator
    generic map (
        BPM_WIDTH => C_AXIS_BPM_WIDTH,
        HRV_WIDTH => C_AXIS_RMSSD_WIDTH,
        BPM_MED   => C_BPM_MEDIUM,  -- tune if you want
        BPM_HIGH  => C_BPM_HIGH,
        HRV_LOW   => C_HRV_LOW,
        HRV_MED   => C_HRV_MEDIUM
    )
    port map (
        bpm_avg      => bpm_avg_tdata,   -- from axis_bpm_avg
        hrv_rmssd    => axis_rmssd_tdata,     -- from axis_rmssd
        stress_level => stress_level_sig
    );
    
inst_bp_to_bcd_inst: uart_word_to_bcd
    port map (
        clk           => clk100,
        rst           => rst_d,
        word16_in     => axis_bpm_tdata,
        word_valid_in => axis_bpm_tvalid,
        bcd_out       => digits_mode0,
        bcd_valid     => instant_bpm_valid
    );
    
avg_bp_to_bcd_inst: uart_word_to_bcd
    port map (
        clk           => clk100,
        rst           => rst_d,
        word16_in     => bpm_avg_tdata,
        word_valid_in => bpm_avg_tvalid,
        bcd_out       => digits_mode1,
        bcd_valid     => average_bpm_valid
    );
    
hrv_to_bcd_inst: uart_word_to_bcd
    port map (
        clk           => clk100,
        rst           => rst_d,
        word16_in     => axis_rmssd_tdata,
        word_valid_in => axis_rmssd_tvalid,
        bcd_out       => digits_mode2,
        bcd_valid     => hrv_valid
    );
    
stress_bcd_inst: uart_word_to_bcd
    port map (
        clk           => clk100,
        rst           => rst_d,
        word16_in     => stress_sig,
        word_valid_in => strs_tvalid,
        bcd_out       => digits_mode3,
        bcd_valid     => stress_valid
    );
    
word_assembly: uart_word_assembler port map(
           clk => clk100,
           rst => rst_d,
           rx_ready => rx_ready_inter,
           rx_byte => rx_byte,
           word16 => word16, 
           word_valid => word_valid
           );
word_to_bcd_inst: uart_word_to_bcd
    port map (
        clk           => clk100,
        rst           => rst_d,
        word16_in     => word16,
        word_valid_in => word_valid,
        bcd_out       => digits_mode4,
        bcd_valid     => rx_valid
    );
    
max_to_bcd_inst: uart_word_to_bcd
    port map (
        clk           => clk100,
        rst           => rst_d,
        word16_in     => max_sig,
        word_valid_in => max_valid,
        bcd_out       => digits_mode5,
        bcd_valid     => max_valid_fin
    );
    
min_to_bcd_inst: uart_word_to_bcd
    port map (
        clk           => clk100,
        rst           => rst_d,
        word16_in     => min_sig,
        word_valid_in => min_valid,
        bcd_out       => digits_mode6,
        bcd_valid     => min_valid_fin
    );
    
min_mod: entity work.min_tracker
    generic map(
        DATA_WIDTH => C_AXIS_BPM_WIDTH
    )
    port map(
        clk           =>clk100,
        rst           => rst_d,

        enable        => v1,

        signal_in     => bpm_avg_tdata,
        signal_valid  => v1,

        minimum_out   =>min_sig,
        minimum_valid => min_valid
    );
    
    
max_mod: entity work.max_tracker
    generic map(
        DATA_WIDTH => C_AXIS_BPM_WIDTH
    )
    port map(
        clk           =>clk100,
        rst           => rst_d,

        enable        => v1,

        signal_in     => bpm_avg_tdata,
        signal_valid  => v1,

        maximum_out   =>max_sig,
        maximum_valid => max_valid
    );
    
valids: process(clk100)
begin
    if rising_edge(clk100) then
        if rst_d = '1' then
            v0_flag <= false;
            v1_flag <= false;
            v2_flag <= false;
            v3_flag <= false;
            v4_flag <= false;
            v5_flag <= false;
            v6_flag <= false;
            v0 <= '0';
            v1 <= '0';
            v2 <= '0';
            v3 <= '0';
            v4 <= '0';
            v5 <= '0';
            v6 <= '0';
        else
            if instant_bpm_valid = '1' and (v0_flag = false) then
                v0_flag <= true;
            end if;
            
            if average_bpm_valid = '1' and (v1_flag = false) then
                v1_flag <= true;
            end if;
            
            if hrv_valid = '1' and (v2_flag = false) then
                v2_flag <= true;
            end if;
            
            if ((v1_flag and v2_flag) = true) and (v3_flag = false) then
                v3_flag <= true;
            end if;

            if rx_valid = '1' and (v4_flag = false) then
                v4_flag <= true;
            end if;
            
            if max_valid_fin = '1' and (v5_flag = false) then
                v5_flag <= true;
            end if;
            
            if min_valid_fin = '1' and (v6_flag = false) then
                v6_flag <= true;
            end if;
            
            if v0_flag = true then
                v0 <= '1';
            end if;
            
            if v1_flag = true then
                v1 <= '1';
            end if;
            
            if v2_flag = true then
                v2 <= '1';
            end if;
            
            if v3_flag = true then
                v3 <= '1';
            end if;
            
            if v4_flag = true then
                v4 <= '1';
            end if;
            
            if v5_flag = true then
                v5 <= '1';
            end if;
            
            if v6_flag = true then
                v6 <= '1';
            end if;
        end if;
    end if;
end process;


stress_sig <= x"000"& "00" & stress_level_sig;

cat<=cat_inter;
an<=an_inter;
strs_tvalid<= v1 and v2;
end Behavioral;
