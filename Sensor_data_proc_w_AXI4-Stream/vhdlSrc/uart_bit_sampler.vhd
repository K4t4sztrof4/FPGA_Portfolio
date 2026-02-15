library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.common_pkg.all;

entity uart_bit_sampler is
  generic (
    CLK_FREQ  : integer := C_CLK_FREQ; 
    BAUD_RATE : integer := C_BAUD_RATE         
  );
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;
    rx         : in  std_logic;

    data_out   : out std_logic_vector(7 downto 0);
    data_ready : out std_logic           -- 1 clk pulse when a byte is received
  );
end entity;

architecture Behavioral of uart_bit_sampler is
  -- Number of clock cycles per bit (rounded)
  constant BAUD_TICKS        : integer := integer(real(CLK_FREQ) / real(BAUD_RATE) + 0.5);
  constant BAUD_TICKS_MINUS1 : integer := BAUD_TICKS - 1;
  constant HALF_TICKS        : integer := BAUD_TICKS / 2;

  type state_t is (IDLE, START, DATA, STOP);
  signal state      : state_t := IDLE;

  signal bit_index  : integer range 0 to 7 := 0;
  signal baud_count : integer := 0;
  signal shift_reg  : std_logic_vector(7 downto 0) := (others => '0');

  -- RX synchronizer (to bring rx into clk domain cleanly)
  signal rx_sync1, rx_sync2, rx_s : std_logic := '1';

begin

  -- Synchronize rx to clk to avoid metastability
  process(clk)
  begin
    if rising_edge(clk) then
      rx_sync1 <= rx;
      rx_sync2 <= rx_sync1;
    end if;
  end process;
  rx_s <= rx_sync2;
  
  --FSM
  process(clk)
  begin
    if rising_edge(clk) then
      data_ready <= '0';

      if rst = '1' then
        state      <= IDLE;
        bit_index  <= 0;
        baud_count <= 0;

      else
        case state is

          when IDLE =>
            --wait for start bit falling edge (line goes low)
            if rx_s = '0' then
              baud_count <= 0;
              state      <= START;
            end if;

          when START =>
            -- wait HALF_TICKS to get to the middle of the start bit
            if baud_count = HALF_TICKS then
              baud_count <= 0;
              bit_index  <= 0;
              state      <= DATA;
            else
              baud_count <= baud_count + 1;
            end if;

          when DATA =>
            -- wait one full bit period between bit samples
            if baud_count = BAUD_TICKS_MINUS1 then
              baud_count <= 0;

              -- Sample the current data bit in the middle of its slot
              shift_reg(bit_index) <= rx_s;  -- LSB first

              if bit_index = 7 then
                state <= STOP;
              else
                bit_index <= bit_index + 1;
              end if;

            else
              baud_count <= baud_count + 1;
            end if;

          when STOP =>
            -- wait one more bit time for stop bit then output the byte
            if baud_count = BAUD_TICKS_MINUS1 then
              data_out   <= shift_reg;
              data_ready <= '1';
              state      <= IDLE;
              baud_count <= 0;
            else
              baud_count <= baud_count + 1;
            end if;

        end case;
      end if;
    end if;
  end process;

end Behavioral;
