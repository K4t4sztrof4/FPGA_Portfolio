library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;  
use STD.TEXTIO.ALL;

entity tb_top_module2 is
end tb_top_module2;

architecture sim of tb_top_module2 is

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
    signal an       : std_logic_vector(3 downto 0);
    signal cat      : std_logic_vector(6 downto 0);
    

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
    dut : entity work.top_level_module
        port map (
            clk100       => clk100,
            JC1          => JC1,
            rst          => rst,
            btnC         => btnC,
            an           => an,
            cat          => cat
        );   

    --------------------------------------------------------------------
    -- Stimulus
    --------------------------------------------------------------------
    stim : process
    file sensors_data : text open read_mode is "C:/Users/skata/Documents/UNIVERSITY/UT_remastered/SCS/Project/pythonProjectSerialInputCapture/ppg_data.csv";
    variable in_line  : line;
    variable ppg_val  : integer;
    variable ppg_slv  : std_logic_vector(15 downto 0);
    variable lo_byte, hi_byte : std_logic_vector(7 downto 0);
    begin
        -- reset pulse
        rst <= '1';
        JC1 <= '1';
        wait for CLK_PERIOD;
        rst <= '0';
    
        -- give DUT some time before data starts
        wait for 100 * BIT_PERIOD;
    
        ----------------------------------------------------------------
        -- Skip header line ("ir")
        ----------------------------------------------------------------
        if not endfile(sensors_data) then
            readline(sensors_data, in_line);
            -- no read() here, it's just the header text
        end if;
    
        ----------------------------------------------------------------
        -- Read all samples until EOF
        ----------------------------------------------------------------
        while not endfile(sensors_data) loop
            -- Get next line from file
            readline(sensors_data, in_line);
    
            -- Parse integer from the line
            -- (assumes each line is just a number like "6123")
            read(in_line, ppg_val);
    
            -- Convert to 16-bit std_logic_vector
            ppg_slv := std_logic_vector(to_unsigned(ppg_val, 16));
    
            -- Split into bytes
            hi_byte := ppg_slv(15 downto 8);
            lo_byte := ppg_slv(7 downto 0);
    
            -- Send over UART
            -- NOTE: if your UART word assembler is LSB-first,
            -- you probably want to send lo_byte first.
            send_uart_byte(JC1, hi_byte, BIT_PERIOD);
            wait for 2 * BIT_PERIOD;
            send_uart_byte(JC1, lo_byte, BIT_PERIOD);

            wait for 2 * BIT_PERIOD;
        end loop;
    
        -- some extra time to observe outputs
        wait for 10 * CLK_PERIOD;
    
        report "End of simulation" severity note;
        wait;
    end process;
    

end sim;
