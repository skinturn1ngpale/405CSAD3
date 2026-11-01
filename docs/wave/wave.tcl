# GTKWave: набір сигналів (SIGSET = ext | int | modes | all) і діапазон часу (нс)
set set $::env(SIGSET)
if {$set eq "ext"} {
  set sigs {
    tb_spi_master.clk tb_spi_master.rst tb_spi_master.start tb_spi_master.tx_data[7:0]
    tb_spi_master.ss_n tb_spi_master.sck tb_spi_master.mosi tb_spi_master.miso
    tb_spi_master.busy tb_spi_master.done tb_spi_master.rx_valid
    tb_spi_master.rx_data[7:0] tb_spi_master.slave_rx[7:0]
  }
} elseif {$set eq "int"} {
  set sigs {
    tb_spi_master.clk tb_spi_master.start tb_spi_master.ss_n
    tb_spi_master.dut.clk_en tb_spi_master.sck
    tb_spi_master.dut.lead_stb tb_spi_master.dut.trail_stb
    tb_spi_master.dut.sample_en tb_spi_master.mosi tb_spi_master.miso
    tb_spi_master.busy
  }
} elseif {$set eq "modes"} {
  set sigs {
    tb_spi_master.ss_n tb_spi_master.sck tb_spi_master.mosi tb_spi_master.miso
    tb_spi_master.rx_data[7:0]
  }
} else {
  set sigs {
    tb_spi_master.ss_n tb_spi_master.sck tb_spi_master.mosi tb_spi_master.miso
    tb_spi_master.tx_data[7:0] tb_spi_master.slave_rx[7:0] tb_spi_master.rx_data[7:0]
    tb_spi_master.done
  }
}
gtkwave::addSignalsFromList $sigs
gtkwave::setZoomRangeTimes $::env(WAVE_FROM)ns $::env(WAVE_TO)ns
