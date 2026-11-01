-- ===========================================================================
-- spi_master_tx.vhd
-- Передавач (Tx) SPI Master + керівний автомат (FSM) транзакції.
--
-- Автомат станів:
--   S_IDLE  - очікування start; ss_n = '1'
--   S_SETUP - ss_n = '0', пауза CLK_DIV тактів перед першим фронтом SCK
--   S_SHIFT - генерується SCK, біти виставляються на MOSI (MSB first)
--   S_HOLD  - SCK зупинено, пауза CLK_DIV тактів, далі ss_n = '1', done
--
-- Фази тактування (CPOL/CPHA):
--   CPHA = 0: дані виставляються заздалегідь (при спаданні SS) і далі
--             змінюються на замикаючому фронті SCK; слейв читає на ведучому.
--   CPHA = 1: дані змінюються на ведучому фронті; слейв читає на замикаючому.
--   Отже, "строб зсуву" = trail_stb (CPHA=0) або lead_stb (CPHA=1).
-- ===========================================================================
library ieee;
use ieee.std_logic_1164.all;

entity spi_master_tx is
  generic (
    CPHA       : std_logic := '0';   -- фаза тактування SPI
    CLK_DIV    : positive  := 6;     -- півперіод SCK у тактах clk
    DATA_WIDTH : positive  := 8      -- розрядність слова (>= 2)
  );
  port (
    clk       : in  std_logic;       -- системна частота
    rst       : in  std_logic;       -- синхронне скидання ('1')
    start     : in  std_logic;       -- імпульс: почати передачу tx_data
    -- слово для передачі
    tx_data   : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
    lead_stb  : in  std_logic;  -- строб ведучого фронту SCK (від spi_clk_gen)
    trail_stb : in  std_logic;       -- строб замикаючого фронту SCK
    clk_en    : out std_logic;       -- дозвіл генератора SCK
    ss_n      : out std_logic;       -- вибір слейва, активний рівень '0'
    mosi      : out std_logic;       -- дані до слейва
    busy      : out std_logic;       -- '1' поки триває транзакція
    done      : out std_logic        -- імпульс: транзакцію завершено
  );
end entity spi_master_tx;

architecture rtl of spi_master_tx is
  type state_t is (S_IDLE, S_SETUP, S_SHIFT, S_HOLD);
  signal state     : state_t := S_IDLE;                    -- стан автомата
  signal shreg     : std_logic_vector(DATA_WIDTH - 1 downto 0)
                     := (others => '0');
  signal bit_cnt   : natural range 0 to DATA_WIDTH - 1 := 0;  -- віддано бітів
  -- таймер пауз SETUP/HOLD
  signal tmr       : natural range 0 to CLK_DIV - 1 := 0;
  signal shift_stb : std_logic;                            -- строб зсуву MOSI
begin

  -- Вибір фронту для зміни даних залежно від CPHA
  shift_stb <= trail_stb when CPHA = '0' else lead_stb;

  clk_en <= '1' when state = S_SHIFT else '0';
  busy   <= '0' when state = S_IDLE  else '1';

  process (clk)
  begin
    if rising_edge(clk) then
      done <= '0';

      if rst = '1' then
        state   <= S_IDLE;
        ss_n    <= '1';
        mosi    <= '0';
        shreg   <= (others => '0');
        bit_cnt <= 0;
        tmr     <= 0;
      else
        case state is

          when S_IDLE =>
            if start = '1' then
              ss_n    <= '0';                      -- вибираємо слейва
              tmr     <= 0;
              bit_cnt <= 0;
              if CPHA = '0' then
                -- CPHA=0: старший біт має бути на MOSI ще до першого фронту
                -- SCK
                mosi  <= tx_data(DATA_WIDTH - 1);
                shreg <= tx_data(DATA_WIDTH - 2 downto 0) & '0';
              else
                mosi  <= '0';
                shreg <= tx_data;
              end if;
              state <= S_SETUP;
            end if;

          when S_SETUP =>  -- затримка SS -> перший SCK
            if tmr = CLK_DIV - 1 then
              tmr   <= 0;
              state <= S_SHIFT;
            else
              tmr <= tmr + 1;
            end if;

          when S_SHIFT =>
            if shift_stb = '1' then  -- виставляємо наступний біт
              mosi  <= shreg(DATA_WIDTH - 1);
              shreg <= shreg(DATA_WIDTH - 2 downto 0) & '0';
            end if;
            if trail_stb = '1' then  -- кінець чергового періоду SCK
              if bit_cnt = DATA_WIDTH - 1 then     -- віддано всі біти
                bit_cnt <= 0;
                tmr     <= 0;
                state   <= S_HOLD;
              else
                bit_cnt <= bit_cnt + 1;
              end if;
            end if;

          when S_HOLD =>  -- затримка останній SCK -> SS
            if tmr = CLK_DIV - 1 then
              ss_n  <= '1';                        -- знімаємо вибір слейва
              mosi  <= '0';
              done  <= '1';
              state <= S_IDLE;
            else
              tmr <= tmr + 1;
            end if;

        end case;
      end if;
    end if;
  end process;

end architecture rtl;
