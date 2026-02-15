library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_axis_saturator is
end tb_axis_saturator;

architecture Behavioral of tb_axis_saturator is

    -- Constants matching DUT generics
    constant DATA_WIDTH : integer := 16;
    constant MIN_VAL    : integer := 1000;
    constant MAX_VAL    : integer := 8192;

    -- DUT ports
    signal aclk          : std_logic := '0';
    signal rst           : std_logic := '0';

    signal s_axis_tdata  : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal s_axis_tvalid : std_logic := '0';
    signal s_axis_tready : std_logic;

    signal m_axis_tdata  : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal m_axis_tvalid : std_logic;
    signal m_axis_tready : std_logic := '0';

    -- Test vectors
    type int_array is array (natural range <>) of integer;
    constant test_values    : int_array(0 to 3) := ( 500, 1000, 5000, 9000 );
    constant expected_values: int_array(0 to 3) := (1000, 1000, 5000, 8192);

begin

    uut: entity work.axis_saturator
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            MIN_VAL    => MIN_VAL,
            MAX_VAL    => MAX_VAL
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

    --100 MHz clock with 10 ns period
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
        variable i : integer;
    begin
        --initial rst
        rst <= '1';
        s_axis_tvalid <= '0';
        m_axis_tready <= '0';
        wait for 50 ns;

        rst <= '0';
        wait for 20 ns;

        -- Ready to accept outputs
        m_axis_tready <= '1';


        for i in test_values'range loop


            s_axis_tdata  <= std_logic_vector(to_unsigned(test_values(i), DATA_WIDTH));
            s_axis_tvalid <= '1';


            wait until rising_edge(aclk);
            while s_axis_tready = '0' loop
                wait until rising_edge(aclk);
            end loop;


            s_axis_tvalid <= '0';


            wait until rising_edge(aclk);
            while m_axis_tvalid = '0' loop
                wait until rising_edge(aclk);
            end loop;


            assert unsigned(m_axis_tdata) = to_unsigned(expected_values(i), DATA_WIDTH)
                report "Mismatch at sample " & integer'image(i) &
                       ". Input="      & integer'image(test_values(i)) &
                       " Expected="    & integer'image(expected_values(i)) &
                       " Got="         & integer'image(to_integer(unsigned(m_axis_tdata)))
                severity error;

            report "Sample " & integer'image(i) &
                   " OK. Input="   & integer'image(test_values(i)) &
                   " Output="      & integer'image(to_integer(unsigned(m_axis_tdata)))
                severity note;


            wait for 20 ns;
        end loop;

        report "All test vectors applied. Simulation finished." severity note;
        wait;
    end process;

end Behavioral;
