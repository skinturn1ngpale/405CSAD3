-- ===========================================================================
-- spi_master_rx.vhd
-- Приймач (Rx) SPI Master: зсувний регістр, що збирає біти з лінії MISO.
--
-- Логіка роботи:
--   1. Лінія MISO асинхронна відносно clk, тому спочатку проходить через
--      дворівневий синхронізатор (захист від метастабільності).
--   2. За стробом sample_en (фронт SCK, на якому слейв тримає дані
--   стабільними:
--      CPHA=0 - ведучий фронт, CPHA=1 - замикаючий) біт зсувається в регістр
--      з молодшого розряду (MSB first).
--   3. Після DATA_WIDTH бітів слово копіюється в rx_data, rx_valid = '1'
--      на один такт.
--   4. Поки передача неактивна (active = '0'), лічильник бітів скинуто.
-- ===========================================================================
library ieee;
use ieee.std_logic_1164.all;

entity spi_master_rx is
  generic (
    DATA_WIDTH : positive := 8                          -- розрядність слова
  );
  port (
    clk       : in  std_logic;                          -- системна частота
    rst       : in  std_logic;  -- синхронне скидання ('1')
    active    : in  std_logic;  -- '1' під час передачі
    sample_en : in  std_logic;  -- строб захоплення біта
    miso      : in  std_logic;                          -- дані від слейва
    -- прийняте слово
    rx_data   : out std_logic_vector(DATA_WIDTH - 1 downto 0);
    rx_valid  : out std_logic  -- імпульс: слово готове
  );
end entity spi_master_rx;

architecture rtl of spi_master_rx is
  signal miso_s1, miso_s2 : std_logic := '0';           -- синхронізатор MISO
  signal shreg   : std_logic_vector(DATA_WIDTH - 1 downto 0)
                   := (others => '0');
  signal bit_cnt : natural range 0 to DATA_WIDTH - 1 := 0;  -- прийнято бітів
  signal rx_reg  : std_logic_vector(DATA_WIDTH - 1 downto 0)
                   := (others => '0');
begin

  rx_data <= rx_reg;

  process (clk)
    variable next_word : std_logic_vector(DATA_WIDTH - 1 downto 0);
  begin
    if rising_edge(clk) then
      -- дворівнева синхронізація лінії MISO
      miso_s1 <= miso;
      miso_s2 <= miso_s1;

      rx_valid <= '0';

      if rst = '1' then
        shreg   <= (others => '0');
        rx_reg  <= (others => '0');
        bit_cnt <= 0;
      elsif active = '0' then
        bit_cnt <= 0;                                   -- між передачами
      elsif sample_en = '1' then
        -- нове слово: попередні біти, зсунуті вліво, + щойно прийнятий біт
        next_word := shreg(DATA_WIDTH - 2 downto 0) & miso_s2;
        shreg <= next_word;
        if bit_cnt = DATA_WIDTH - 1 then  -- прийнято останній біт
          rx_reg   <= next_word;
          rx_valid <= '1';
          bit_cnt  <= 0;
        else
          bit_cnt <= bit_cnt + 1;
        end if;
      end if;
    end if;
  end process;

end architecture rtl;
