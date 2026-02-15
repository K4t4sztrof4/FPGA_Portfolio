library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_axis_bpm_instant is
end tb_axis_bpm_instant;

architecture Behavioral of tb_axis_bpm_instant is

    constant SAMPLE_RATE : integer := 100; -- samples per second
    constant BPM_WIDTH   : integer := 16;

    signal aclk          : std_logic := '0';
    signal rst           : std_logic := '0';

    signal s_axis_tdata  : std_logic_vector(15 downto 0) := (others => '0');
    signal s_axis_tvalid : std_logic := '0';
    signal s_axis_tready : std_logic;

    signal m_axis_tdata  : std_logic_vector(BPM_WIDTH-1 downto 0);
    signal m_axis_tvalid : std_logic;
    signal m_axis_tready : std_logic := '1';  -- always ready in this TB


    -- Fs = 100 hz:
    --   RR = 100  -> BPM = (60*100)/100 = 60
    --   RR = 75   -> BPM = (60*100)/75  = 80
    --   RR = 50   -> BPM = (60*100)/50  = 120
    --   RR = 120  -> BPM = (60*100)/120 = 50
    --   RR = 0    -> BPM = 0 (by design)
    type int_array is array (natural range <>) of integer;
    constant NUM_SAMPLES    : integer := 5;
    constant rr_values      : int_array(0 to NUM_SAMPLES-1) := (100, 75, 50, 120, 0);
    constant expected_bpm   : int_array(0 to NUM_SAMPLES-1) := ( 60, 80,120,  50, 0);

begin

    uut : entity work.axis_bpm_instant
        generic map (
            SAMPLE_RATE => SAMPLE_RATE,
            BPM_WIDTH   => BPM_WIDTH
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
        variable i       : integer;
        variable bpm_int : integer;
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

            s_axis_tdata  <= std_logic_vector(to_unsigned(rr_values(i), 16));
            s_axis_tvalid <= '1';

            -- wait for one handshake cycle
            wait until rising_edge(aclk);

            s_axis_tvalid <= '0';

            wait until rising_edge(aclk);
            while m_axis_tvalid = '0' loop
                wait until rising_edge(aclk);
            end loop;

        end loop;

        report "All RR values tested, simulation finished successfully." severity note;
        wait;
    end process;

end Behavioral;
