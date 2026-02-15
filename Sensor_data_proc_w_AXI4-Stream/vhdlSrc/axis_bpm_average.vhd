library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity axis_bpm_avg is
    generic (
        BPM_WIDTH   : integer := 16;
        WINDOW_SIZE : integer := 8         -- number of samples in average
    );
    port (
        aclk          : in  std_logic;
        rst           : in  std_logic;     -- active high

        -- AXI4-Stream slave (instant BPM)
        s_axis_tdata  : in  std_logic_vector(BPM_WIDTH-1 downto 0);
        s_axis_tvalid : in  std_logic;
        s_axis_tready : out std_logic;

        -- AXI4-Stream master (averaged BPM)
        m_axis_tdata  : out std_logic_vector(BPM_WIDTH-1 downto 0);
        m_axis_tvalid : out std_logic;
        m_axis_tready : in  std_logic
    );
end axis_bpm_avg;

architecture Behavioral of axis_bpm_avg is

    type int_array is array (natural range <>) of integer;

    constant MAX_BPM     : integer := 2**BPM_WIDTH - 1;
    constant SUM_MAX     : integer := MAX_BPM * WINDOW_SIZE;

    signal window        : int_array(0 to WINDOW_SIZE-1) := (others => 0);
    signal index         : integer range 0 to WINDOW_SIZE-1 := 0;
    signal filled_count  : integer range 0 to WINDOW_SIZE   := 0;

    signal sum_acc       : integer range 0 to SUM_MAX := 0;

    signal avg_reg       : std_logic_vector(BPM_WIDTH-1 downto 0) := (others => '0');
    signal avg_valid_reg : std_logic := '0';

    signal s_axis_tready_int : std_logic;

begin

    -- Ready when output buffer is free or downstream just consumed it
    s_axis_tready_int <= '1' when (avg_valid_reg = '0') or
                                (avg_valid_reg = '1' and m_axis_tready = '1')
                         else '0';

    process(aclk)
        variable in_bpm     : integer;
        variable new_sum    : integer;
        variable avg_int    : integer;
    begin
        if rising_edge(aclk) then
            if rst = '1' then
                index         <= 0;
                filled_count  <= 0;
                sum_acc       <= 0;
                avg_reg       <= (others => '0');
                avg_valid_reg <= '0';
                window        <= (others => 0);
            else
                -- Drop valid when downstream consumes the average
                if (avg_valid_reg = '1') and (m_axis_tready = '1') then
                    avg_valid_reg <= '0';
                end if;

                -- New BPM sample?
                if (s_axis_tvalid = '1') and (s_axis_tready_int = '1') then
                    in_bpm := to_integer(unsigned(s_axis_tdata));

                    if filled_count < WINDOW_SIZE then
                        -- Still filling the window
                        new_sum       := sum_acc + in_bpm;
                        window(index) <= in_bpm;
                        sum_acc       <= new_sum;
                        filled_count  <= filled_count + 1;
                        index         <= (index + 1) mod WINDOW_SIZE;

                        -- Output only after the window is full
                        if filled_count + 1 = WINDOW_SIZE then
                            avg_int := new_sum / WINDOW_SIZE;
                            if avg_int < 0 then
                                avg_int := 0;
                            elsif avg_int > MAX_BPM then
                                avg_int := MAX_BPM;
                            end if;
                            avg_reg       <= std_logic_vector(to_unsigned(avg_int, BPM_WIDTH));
                            avg_valid_reg <= '1';
                        end if;
                    else
                        -- Window full: sliding average
                        new_sum       := sum_acc - window(index) + in_bpm;
                        sum_acc       <= new_sum;
                        window(index) <= in_bpm;
                        index         <= (index + 1) mod WINDOW_SIZE;

                        avg_int := new_sum / WINDOW_SIZE;
                        if avg_int < 0 then
                            avg_int := 0;
                        elsif avg_int > MAX_BPM then
                            avg_int := MAX_BPM;
                        end if;

                        avg_reg       <= std_logic_vector(to_unsigned(avg_int, BPM_WIDTH));
                        avg_valid_reg <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process;

    s_axis_tready <= s_axis_tready_int;
    m_axis_tdata  <= avg_reg;
    m_axis_tvalid <= avg_valid_reg;

end Behavioral;
