#!/usr/bin/env bash
# Запуск симуляції SPI Master у GHDL для всіх 4 режимів SPI.
# Потрібно: ghdl (https://github.com/ghdl/ghdl). Для осцилограм: gtkwave.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

W=sim/work
mkdir -p "$W" sim/out
ghdl -a --std=08 --workdir="$W" \
  hdl/spi_clk_gen.vhd hdl/spi_master_rx.vhd hdl/spi_master_tx.vhd hdl/spi_master.vhd \
  tb/tb_spi_master.vhd
ghdl -e --std=08 --workdir="$W" tb_spi_master

for mode in 0 1 2 3; do
  cpol=$((mode / 2)); cpha=$((mode % 2))
  echo "---- SPI mode $mode (CPOL=$cpol, CPHA=$cpha) ----"
  ghdl -r --std=08 --workdir="$W" tb_spi_master \
    -gCPOL_I=$cpol -gCPHA_I=$cpha --vcd="sim/out/spi_mode${mode}.vcd" \
    2>&1 | tee "sim/out/spi_mode${mode}.log"
done
echo "Готово. VCD-файли: sim/out/spi_mode*.vcd (відкрити: gtkwave sim/out/spi_mode0.vcd)"
