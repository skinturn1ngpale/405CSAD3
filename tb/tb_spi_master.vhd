-- ===========================================================================
-- tb_spi_master.vhd
-- Testbench для SPI Master (VHDL-2008).
--
-- Що імітується:
--   * тактовий сигнал clk 12 МГц і скидання rst;
--   * користувач, який подає тестові слова на вхід передавача
--   (start/tx_data);
--   * зовнішній SPI Slave (поведінкова модель), що
--       - приймає MOSI і запам'ятовує слово (перевірка передачі Tx),
--       - видає своє слово на MISO (перевірка прийому Rx).
-- Що перевіряється автоматично (assert):
--   1. слово, прийняте слейвом, = слово, надіслане master-ом;
--   2. слово, прийняте master-ом (rx_data), = слово, надіслане слейвом;
--   3. кількість імпульсів SCK за транзакцію = DATA_WIDTH;
--   4. період SCK = 2 * CLK_DIV * T_clk;
--   5. сигнал SS низький лише під час транзакції.
-- Режим SPI задається generic-ами CPOL_I / CPHA_I (0..1), тому один і той
-- самий
-- тест запускається для всіх 4 режимів: ghdl -r tb_spi_master -gCPOL_I=1 ...
-- ===========================================================================
library ieee;
use ieee.std_logic_1164.all;
use std.env.all;

entity tb_spi_master is
  generic (
    CPOL_I : integer := 0;   -- полярність SCK (0/1)
    CPHA_I : integer := 0    -- фаза тактування (0/1)
  );
end entity tb_spi_master;

architecture sim of tb_spi_master is

  function to_sl(i : integer) return std_logic is
  begin
    if i = 1 then return '1'; else return '0'; end if;
  end function;

  constant CPOL       : std_logic := to_sl(CPOL_I);
  constant CPHA       : std_logic := to_sl(CPHA_I);
  constant CLK_PERIOD : time      := 83334 ps;   -- 12 МГц
  constant CLK_DIV    : positive  := 6;          -- f_SCK = 1 МГц
  constant T_CO       : time      := 20 ns;      -- затримка виходу слейва
  constant WIDTH      : positive  := 8;

  signal clk      : std_logic := '0';
  signal rst      : std_logic := '1';
  signal start    : std_logic := '0';
  signal tx_data  : std_logic_vector(WIDTH - 1 downto 0) := (others => '0');
  signal busy     : std_logic;
  signal done     : std_logic;
  signal rx_data  : std_logic_vector(WIDTH - 1 downto 0);
  signal rx_valid : std_logic;
  signal sck      : std_logic;
  signal mosi     : std_logic;
  signal miso     : std_logic := '0';
  signal ss_n     : std_logic := '1';

  -- сигнали моделі слейва
  -- що слейв передає / що слейв прийняв
  signal slave_tx   : std_logic_vector(WIDTH - 1 downto 0) := (others => '0');
  signal slave_rx   : std_logic_vector(WIDTH - 1 downto 0) := (others => '0');
  signal slave_bits : natural := 0;  -- імпульсів SCK у кадрі
  signal frame_err  : natural := 0;  -- помилки довжини кадру (слейв)
  signal period_err : natural := 0;  -- помилки періоду SCK

begin

  -- -------------------------------------------------------------------------
  -- Тактовий сигнал
  -- -------------------------------------------------------------------------
  clk <= not clk after CLK_PERIOD / 2;

  -- -------------------------------------------------------------------------
  -- Перевіряється модуль
  -- -------------------------------------------------------------------------
  dut : entity work.spi_master
    generic map (CPOL => CPOL, CPHA => CPHA, CLK_DIV => CLK_DIV,
                 DATA_WIDTH => WIDTH)
    port map (clk => clk, rst => rst, start => start, tx_data => tx_data,
              busy => busy, done => done, rx_data => rx_data,
              rx_valid => rx_valid, sck => sck, mosi => mosi, miso => miso,
              ss_n => ss_n);

  -- -------------------------------------------------------------------------
  -- Модель SPI Slave (для заданих CPOL/CPHA)
  --   "фронт вибірки"  : CPHA=0 - ведучий, CPHA=1 - замикаючий -> слейв читає
  --   MOSI
  --   "фронт зсуву"    : протилежний                           -> слейв міняє
  --   MISO
  -- -------------------------------------------------------------------------
  slave : process (ss_n, sck)
    variable tx_sh   : std_logic_vector(WIDTH - 1 downto 0);
    variable rx_sh   : std_logic_vector(WIDTH - 1 downto 0);
    variable cnt     : natural := 0;
    variable is_lead : boolean;
  begin
    if falling_edge(ss_n) then  -- слейва вибрано: починається кадр
      tx_sh := slave_tx;
      rx_sh := (others => '0');
      cnt   := 0;
      slave_bits <= 0;
      if CPHA = '0' then                      -- перший біт видається одразу
        miso  <= tx_sh(WIDTH - 1) after T_CO;
        tx_sh := tx_sh(WIDTH - 2 downto 0) & '0';
      end if;
    elsif rising_edge(ss_n) then              -- кадр завершено
      miso <= '0' after T_CO;
      if cnt /= WIDTH then
        report "Slave: SCK pulses in frame = " & integer'image(cnt)
               & ", expected " & integer'image(WIDTH) severity error;
        frame_err <= frame_err + 1;
      end if;
    elsif ss_n = '0' and sck'event then
      is_lead := (sck /= CPOL);  -- ведучий фронт = вихід зі стану спокою
      if is_lead = (CPHA = '0') then          -- фронт вибірки
        rx_sh := rx_sh(WIDTH - 2 downto 0) & mosi;
        cnt   := cnt + 1;
        slave_bits <= cnt;
        if cnt = WIDTH then
          slave_rx <= rx_sh;
        end if;
      else                                    -- фронт зсуву
        miso  <= tx_sh(WIDTH - 1) after T_CO;
        tx_sh := tx_sh(WIDTH - 2 downto 0) & '0';
      end if;
    end if;
  end process slave;

  -- -------------------------------------------------------------------------
  -- Перевірка періоду SCK (між сусідніми ведучими фронтами)
  -- -------------------------------------------------------------------------
  sck_period : process (sck, ss_n)
    variable t_prev  : time    := 0 ns;
    variable have_t  : boolean := false;
  begin
    if falling_edge(ss_n) then
      have_t := false;
    elsif ss_n = '0' and sck'event and sck /= CPOL then   -- ведучий фронт
      if have_t and (now - t_prev) /= 2 * CLK_DIV * CLK_PERIOD then
        report "Wrong SCK period: " & time'image(now - t_prev) severity error;
        period_err <= period_err + 1;
      end if;
      t_prev := now;
      have_t := true;
    end if;
  end process sck_period;

  -- -------------------------------------------------------------------------
  -- Сценарій тесту
  -- -------------------------------------------------------------------------
  stim : process
    type byte_arr is array (natural range <>) of
      std_logic_vector(WIDTH - 1 downto 0);
    -- слова master -> slave (MOSI) і slave -> master (MISO)
    constant M_DATA : byte_arr(0 to 7) :=
      (x"A5", x"3C", x"FF", x"00", x"81", x"5A", x"01", x"80");
    constant S_DATA : byte_arr(0 to 7) :=
      (x"5A", x"C3", x"00", x"FF", x"7E", x"A5", x"80", x"01");
    variable errors : natural := 0;
  begin
    -- скидання
    rst <= '1';
    wait for 5 * CLK_PERIOD;
    wait until rising_edge(clk);
    rst <= '0';
    wait for 3 * CLK_PERIOD;

    assert ss_n = '1' and busy = '0' and sck = CPOL
      report "After reset: SS must be 1, busy 0, SCK = CPOL" severity error;

    report "=== SPI Master: mode CPOL=" & integer'image(CPOL_I)
           & " CPHA=" & integer'image(CPHA_I) & " ===";

    for i in M_DATA'range loop
      slave_tx <= S_DATA(i);  -- слово, яке слейв поверне на MISO
      wait until rising_edge(clk);
      tx_data <= M_DATA(i);                   -- слово, яке передає master
      start   <= '1';
      wait until rising_edge(clk);
      start   <= '0';

      wait until rising_edge(clk) and done = '1';   -- чекаємо завершення
      wait for 1 ns;

      if slave_rx /= M_DATA(i) then           -- перевірка Tx
        report "ERROR Tx #" & integer'image(i) & ": slave got 0x"
               & to_hstring(slave_rx) & ", expected 0x"
               & to_hstring(M_DATA(i))
               severity error;
        errors := errors + 1;
      end if;
      if rx_data /= S_DATA(i) then            -- перевірка Rx
        report "ERROR Rx #" & integer'image(i) & ": master got 0x"
               & to_hstring(rx_data) & ", expected 0x" & to_hstring(S_DATA(i))
               severity error;
        errors := errors + 1;
      end if;
      assert ss_n = '1' and busy = '0'
        report "After done: SS must be 1 and busy 0" severity error;

      report "Transfer #" & integer'image(i)
             & ": MOSI=0x" & to_hstring(M_DATA(i))
             & " -> slave=0x" & to_hstring(slave_rx)
             & " | MISO=0x" & to_hstring(S_DATA(i))
             & " -> master=0x" & to_hstring(rx_data);
      wait for 3 * CLK_PERIOD;
    end loop;

    errors := errors + frame_err + period_err;
    if errors = 0 then
      report "TEST PASSED: CPOL=" & integer'image(CPOL_I)
             & " CPHA=" & integer'image(CPHA_I) & ", "
             & integer'image(M_DATA'length) & "/"
             & integer'image(M_DATA'length) & " transfers OK";
      finish;
    else
      report "TEST FAILED: errors = " & integer'image(errors)
        severity failure;
    end if;
    wait;
  end process stim;

end architecture sim;
