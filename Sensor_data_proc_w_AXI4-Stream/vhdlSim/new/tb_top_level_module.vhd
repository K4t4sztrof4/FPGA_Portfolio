library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;  
use STD.TEXTIO.ALL;

entity tb_top_level_module is
end tb_top_level_module;

architecture sim of tb_top_level_module is

    --------------------------------------------------------------------
    -- Constants
    --------------------------------------------------------------------
    constant CLK_PERIOD : time := 10 ns;          -- 100 MHz
    constant BAUD_RATE  : integer := 115200;
    constant BIT_PERIOD : time := 1 sec / BAUD_RATE;  -- ~8.68 us

    --------------------------------------------------------------------
    -- DUT ports
    --------------------------------------------------------------------
    signal clk100   : std_logic := '0';
    signal JC1      : std_logic := '1';  -- UART idle high
    signal rst      : std_logic := '0';
    signal btnC     : std_logic := '0';
    signal data_out : std_logic_vector(15 downto 0);

    -- Seeds for uniform() RNG
    -- (any positive values are fine, just not 0)
    -- If your tool complains about shared variables, move them into the process as plain variables.
    shared variable seed1 : positive := 12;
    shared variable seed2 : positive := 543;
    
    
    signal end_of_reading : std_logic := '0';
    --------------------------------------------------------------------
    -- UART send procedure (8N1, LSB first, matches Arduino Serial)
    --------------------------------------------------------------------
    procedure send_uart_byte(
    signal line        : out std_logic;
    constant data      : std_logic_vector(7 downto 0);
    constant bit_period: time
    ) is
    begin
        -- idle high
        line <= '1';
        wait for bit_period;
    
        -- start bit
        line <= '0';
        wait for bit_period;
    
        -- 8 data bits, LSB first
        for i in 0 to 7 loop
            line <= data(i);
            wait for bit_period;
        end loop;
    
        -- stop bit
        line <= '1';
        wait for bit_period;
    end procedure;
    
    
begin

    --------------------------------------------------------------------
    -- Clock generator
    --------------------------------------------------------------------
    clk_proc : process
    begin
        clk100 <= '0';
        wait for CLK_PERIOD/2;
        clk100 <= '1';
        wait for CLK_PERIOD/2;
    end process;

    --------------------------------------------------------------------
    -- DUT instance
    --------------------------------------------------------------------
    dut : entity work.debug
        port map (
            clk100       => clk100,
            JC1          => JC1,
            rst          => rst,
            btnC         => btnC,
            data_out     => data_out
        );   

    --------------------------------------------------------------------
    -- Stimulus
    --------------------------------------------------------------------
    stim : process
    variable rand_real : real;
    variable two : integer := 2;
    variable rand_word, ppg_word : integer;
    variable ppg_std_logic_word : std_logic_vector(15 downto 0);
    variable lo_byte, hi_byte : std_logic_vector(7 downto 0);
    
    file sensors_data : text open read_mode is "ppg_data.csv";
    variable in_line : line;
    variable ppg_val : integer;
    begin
    -- idle high for a while
    -- reset pulse
    rst <= '1';
    JC1 <= '1';
    wait for CLK_PERIOD;
    rst <= '0';

    wait for 100 * BIT_PERIOD;
    
    for i in 0 to 15895 loop
       
    readline(sensors_data, in_line);
    read(in_line, ppg_val);
    -- Generate a random real in (0.0, 1.0)
--    uniform(seed1, seed2, rand_real);

--    ppg_word := integer(rand_real * 2800.0) + 6000;
--    ppg_std_logic_word := std_logic_vector(to_unsigned(ppg_word, 16));
    ppg_std_logic_word := std_logic_vector(to_unsigned(ppg_val, 16));

    hi_byte:= ppg_std_logic_word(15 downto 8);
    lo_byte:= ppg_std_logic_word(7 downto 0);
    
    send_uart_byte(JC1, hi_byte, BIT_PERIOD);
    wait for 2 * BIT_PERIOD;
    send_uart_byte(JC1, lo_byte, BIT_PERIOD);
    wait for 2 * BIT_PERIOD;

    end loop;
    

    -- wait so you can inspect signals
    wait for 10 * CLK_PERIOD;

        report "End of simulation" severity note;
        wait;
    end process;

end sim;
