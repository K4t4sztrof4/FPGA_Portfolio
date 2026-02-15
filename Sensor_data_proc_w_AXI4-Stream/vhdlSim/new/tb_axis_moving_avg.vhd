library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity tb_axis_moving_avg is
end tb_axis_moving_avg;

architecture tb of tb_axis_moving_avg is

    constant DATA_WIDTH  : integer := 16;
    constant WINDOW_SIZE : integer := 4;
    constant SUM_WIDTH   : integer := 20;
    constant SHIFT_BITS  : integer := 2;

    constant CLK_PERIOD : time := 10 ns;  -- 100 MHz

    signal aclk          : std_logic := '0';
    signal rst           : std_logic := '0';

    signal s_axis_tdata  : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal s_axis_tvalid : std_logic := '0';
    signal s_axis_tready : std_logic;

    signal m_axis_tdata  : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal m_axis_tvalid : std_logic;
    signal m_axis_tready : std_logic := '1';  -- always ready

begin

    dut: entity work.axis_moving_avg
        generic map (
            DATA_WIDTH  => DATA_WIDTH,
            WINDOW_SIZE => WINDOW_SIZE,
            SUM_WIDTH   => SUM_WIDTH,
            SHIFT_BITS  => SHIFT_BITS
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

    
    -- Clock generation - 100 Mhz
    clk_proc : process
    begin
        aclk <= '0';
        wait for CLK_PERIOD/2;
        aclk <= '1';
        wait for CLK_PERIOD/2;
    end process;

    stim_proc : process
        -- local helper to wait for one rising edge
        procedure wait_clk is
        begin
            wait until rising_edge(aclk);
        end procedure;
    begin
        -- Initial reset
        rst <= '1';
        s_axis_tvalid <= '0';
        s_axis_tdata  <= (others => '0');
        wait for 5 * CLK_PERIOD;
        rst <= '0';
        wait_clk;

        s_axis_tvalid <= '1';

        -- Sample 1: 10
        s_axis_tdata <= conv_std_logic_vector(10, DATA_WIDTH);
        wait_clk;

        -- Sample 2: 20
        s_axis_tdata <= conv_std_logic_vector(20, DATA_WIDTH);
        wait_clk;

        -- Sample 3: 30
        s_axis_tdata <= conv_std_logic_vector(30, DATA_WIDTH);
        wait_clk;

        -- Sample 4: 40
        s_axis_tdata <= conv_std_logic_vector(40, DATA_WIDTH);
        wait_clk;

        -- Sample 5: 50
        s_axis_tdata <= conv_std_logic_vector(50, DATA_WIDTH);
        wait_clk;

        -- Sample 6: 60
        s_axis_tdata <= conv_std_logic_vector(60, DATA_WIDTH);
        wait_clk;

        -- Sample 7: 70
        s_axis_tdata <= conv_std_logic_vector(70, DATA_WIDTH);
        wait_clk;

        -- Sample 8: 80
        s_axis_tdata <= conv_std_logic_vector(80, DATA_WIDTH);
        wait_clk;

        -- Deassert valid after last sample
        s_axis_tvalid <= '0';
        s_axis_tdata  <= (others => '0');

        -- Let it run a bit more to observe outputs
        wait for 20 * CLK_PERIOD;
        wait;
    end process;

end tb;
