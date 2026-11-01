#!/usr/bin/env bash
# Синтез SPI Master для Lattice iCE40 HX8K (відкритий тулчейн: GHDL + Yosys + nextpnr).
# Потрібно: ghdl, yosys з ghdl-плагіном, nextpnr-ice40.
# Цільова частота: 12 МГц (тактовий генератор плати iCE40-HX8K Breakout).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
OUT=out; mkdir -p "$OUT"
FREQ=${FREQ:-12}

# 1. Синтез VHDL -> netlist (JSON); звіт про ресурси - у yosys_stat.txt
yosys -m ghdl -p "
  ghdl --std=08 ../hdl/spi_clk_gen.vhd ../hdl/spi_master_rx.vhd ../hdl/spi_master_tx.vhd ../hdl/spi_master.vhd -e spi_master;
  synth_ice40 -top spi_master -json $OUT/spi_master.json;
  tee -o $OUT/yosys_stat.txt stat
" > "$OUT/yosys.log" 2>&1

# 2. Розміщення і трасування + часовий аналіз (Fmax) для HX8K
nextpnr-ice40 --hx8k --package ct256 --json "$OUT/spi_master.json" \
  --freq "$FREQ" --pcf-allow-unconstrained --seed 1 \
  > "$OUT/nextpnr.log" 2>&1

grep -E "Info: +(ICESTORM_LC|SB_|ICESTORM_RAM|SB_IO|SB_GB)|Max frequency|Device utilisation" "$OUT/nextpnr.log" || true
