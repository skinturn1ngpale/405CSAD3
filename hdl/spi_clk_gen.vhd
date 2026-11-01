-- ===========================================================================
-- spi_clk_gen.vhd
-- Генератор тактового сигналу SCK для SPI Master (Лабораторна робота,
-- SPI/VHDL)
--
-- Призначення:
--   * ділить системну частоту clk: f_SCK = f_clk / (2 * CLK_DIV);
--   * формує SCK із потрібним неактивним рівнем (CPOL);
--   * видає одно-тактові строби фронтів SCK:
--       lead_stb  - перший (ведучий, leading) фронт кожного періоду SCK
--                   (CPOL=0: наростаючий, CPOL=1: спадний);
--       trail_stb - другий (замикаючий, trailing) фронт.
--     Строб виставляється в тому ж такті, у якому SCK змінює рівень, тому
--     Tx/Rx працюють синхронно з системним clk (без другого тактового
--     домену).
-- ===========================================================================
library ieee;
use ieee.std_logic_1164.all;

entity spi_clk_gen is
  generic (
    CPOL    : std_logic := '0';   -- рівень SCK у стані спокою
    CLK_DIV : positive  := 6      -- півперіод SCK у тактах clk (>= 1)
  );
  port (
    clk       : in  std_logic;    -- системна частота
    rst       : in  std_logic;    -- синхронне скидання, активний рівень '1'
    clk_en    : in  std_logic;    -- '1' - генерувати SCK; '0' - SCK у спокої
    sck       : out std_logic;    -- вихідний тактовий сигнал SPI
    lead_stb  : out std_logic;    -- строб ведучого фронту SCK
    trail_stb : out std_logic     -- строб замикаючого фронту SCK
  );
end entity spi_clk_gen;

architecture rtl of spi_clk_gen is
  -- лічильник півперіоду
  signal cnt     : natural range 0 to CLK_DIV - 1 := 0;
  signal sck_int : std_logic := CPOL;  -- поточний рівень SCK
  signal tick    : std_logic;                            -- кінець півперіоду
begin

  -- Півперіод завершується, коли лічильник досяг CLK_DIV-1 при активному
  -- clk_en
  tick <= '1' when (clk_en = '1' and cnt = CLK_DIV - 1) else '0';

  -- Ведучий фронт: SCK виходить зі стану спокою; замикаючий: повертається в
  -- нього
  lead_stb  <= tick when sck_int = CPOL  else '0';
  trail_stb <= tick when sck_int /= CPOL else '0';

  sck <= sck_int;

  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' or clk_en = '0' then
        cnt     <= 0;             -- поза передачею лічильник скинуто,
        sck_int <= CPOL;          -- а SCK тримає неактивний рівень
      elsif cnt = CLK_DIV - 1 then
        cnt     <= 0;
        sck_int <= not sck_int;   -- зміна рівня SCK (фронт)
      else
        cnt <= cnt + 1;
      end if;
    end if;
  end process;

end architecture rtl;
