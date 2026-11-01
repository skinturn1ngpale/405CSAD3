-- ===========================================================================
-- spi_master.vhd
-- Верхній рівень SPI Master (режими 0-3, MSB first, повнодуплексний).
--
-- Структура:
--   spi_clk_gen   - генератор SCK і строби фронтів
--   spi_master_tx - передавач + FSM транзакції (керує SS, MOSI, SCK_EN)
--   spi_master_rx - приймач (захоплює MISO)
--
-- Порти керування (користувацький інтерфейс):
--   start/tx_data - запуск передачі слова tx_data (приймається, коли busy =
--   '0')
--   busy/done     - стан транзакції; done - імпульс завершення
--   rx_data       - слово, прийняте від слейва під час останньої транзакції
--
-- Налаштування:
--   CPOL/CPHA   - режим SPI (0..3);  CLK_DIV - f_SCK = f_clk / (2*CLK_DIV);
--   DATA_WIDTH  - розрядність слова.
--   CLK_DIV >= 4 потрібно, щоб дворівневий синхронізатор MISO встигав
--   відпрацювати між сусідніми фронтами SCK.
-- ===========================================================================
library ieee;
use ieee.std_logic_1164.all;

entity spi_master is
  generic (
    CPOL       : std_logic := '0';   -- полярність SCK
    CPHA       : std_logic := '0';   -- фаза тактування
    CLK_DIV    : positive  := 6;     -- 12 МГц / (2*6) = 1 МГц SCK
    DATA_WIDTH : positive  := 8
  );
  port (
    clk      : in  std_logic;  -- системна частота
    rst      : in  std_logic;  -- скидання ('1')
    -- користувацький інтерфейс
    start    : in  std_logic;  -- імпульс запуску
    -- дані для передачі
    tx_data  : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
    busy     : out std_logic;  -- транзакція триває
    done     : out std_logic;  -- імпульс: завершено
    -- прийняті дані
    rx_data  : out std_logic_vector(DATA_WIDTH - 1 downto 0);
    rx_valid : out std_logic;  -- імпульс: слово прийнято
    -- шина SPI
    sck      : out std_logic;
    mosi     : out std_logic;
    miso     : in  std_logic;
    ss_n     : out std_logic
  );
end entity spi_master;

architecture rtl of spi_master is
  signal clk_en    : std_logic;   -- дозвіл SCK (з автомата Tx)
  signal lead_stb  : std_logic;   -- ведучий фронт SCK
  signal trail_stb : std_logic;   -- замикаючий фронт SCK
  signal sample_en : std_logic;   -- строб захоплення MISO
begin

  assert CLK_DIV >= 4 and DATA_WIDTH >= 2
    report "spi_master: CLK_DIV >= 4 and DATA_WIDTH >= 2 are required"
    severity failure;

  -- Слейв міняє MISO на "зсувному" фронті, а master читає на протилежному
  sample_en <= lead_stb when CPHA = '0' else trail_stb;

  u_clk : entity work.spi_clk_gen
    generic map (CPOL => CPOL, CLK_DIV => CLK_DIV)
    port map (clk => clk, rst => rst, clk_en => clk_en, sck => sck,
              lead_stb => lead_stb, trail_stb => trail_stb);

  u_tx : entity work.spi_master_tx
    generic map (CPHA => CPHA, CLK_DIV => CLK_DIV, DATA_WIDTH => DATA_WIDTH)
    port map (clk => clk, rst => rst, start => start, tx_data => tx_data,
              lead_stb => lead_stb, trail_stb => trail_stb,
              clk_en => clk_en, ss_n => ss_n, mosi => mosi,
              busy => busy, done => done);

  u_rx : entity work.spi_master_rx
    generic map (DATA_WIDTH => DATA_WIDTH)
    port map (clk => clk, rst => rst, active => clk_en,
              sample_en => sample_en, miso => miso,
              rx_data => rx_data, rx_valid => rx_valid);

end architecture rtl;
