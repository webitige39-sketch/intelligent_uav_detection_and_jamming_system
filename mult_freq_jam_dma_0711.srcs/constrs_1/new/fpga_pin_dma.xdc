
#fpga pin

# "LCD"


# constraints
# ad9361



set_property -dict {PACKAGE_PIN AF15 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports rx_clk_in_p]
set_property -dict {PACKAGE_PIN AG15 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports rx_clk_in_n]
set_property -dict {PACKAGE_PIN AE13 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports rx_frame_in_p]
set_property -dict {PACKAGE_PIN AF13 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports rx_frame_in_n]
set_property -dict {PACKAGE_PIN AH14 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports {rx_data_in_p[0]}]
set_property -dict {PACKAGE_PIN AH13 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports {rx_data_in_n[0]}]
set_property -dict {PACKAGE_PIN AJ15 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports {rx_data_in_p[1]}]
set_property -dict {PACKAGE_PIN AK15 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports {rx_data_in_n[1]}]
set_property -dict {PACKAGE_PIN AH17 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports {rx_data_in_p[2]}]
set_property -dict {PACKAGE_PIN AH16 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports {rx_data_in_n[2]}]
set_property -dict {PACKAGE_PIN AC14 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports {rx_data_in_p[3]}]
set_property -dict {PACKAGE_PIN AC13 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports {rx_data_in_n[3]}]
set_property -dict {PACKAGE_PIN AE12 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports {rx_data_in_p[4]}]
set_property -dict {PACKAGE_PIN AF12 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports {rx_data_in_n[4]}]
set_property -dict {PACKAGE_PIN AD14 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports {rx_data_in_p[5]}]
set_property -dict {PACKAGE_PIN AD13 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports {rx_data_in_n[5]}]




set_property -dict {PACKAGE_PIN AJ16 IOSTANDARD LVDS_25} [get_ports tx_clk_out_p]
set_property -dict {PACKAGE_PIN AK16 IOSTANDARD LVDS_25} [get_ports tx_clk_out_n]
set_property -dict {PACKAGE_PIN AA15 IOSTANDARD LVDS_25} [get_ports tx_frame_out_p]
set_property -dict {PACKAGE_PIN AA14 IOSTANDARD LVDS_25} [get_ports tx_frame_out_n]
set_property -dict {PACKAGE_PIN AD16 IOSTANDARD LVDS_25} [get_ports {tx_data_out_p[0]}]
set_property -dict {PACKAGE_PIN AD15 IOSTANDARD LVDS_25} [get_ports {tx_data_out_n[0]}]
set_property -dict {PACKAGE_PIN AE16 IOSTANDARD LVDS_25} [get_ports {tx_data_out_p[1]}]
set_property -dict {PACKAGE_PIN AE15 IOSTANDARD LVDS_25} [get_ports {tx_data_out_n[1]}]
set_property -dict {PACKAGE_PIN AF19 IOSTANDARD LVDS_25} [get_ports {tx_data_out_p[2]}]
set_property -dict {PACKAGE_PIN AG19 IOSTANDARD LVDS_25} [get_ports {tx_data_out_n[2]}]
set_property -dict {PACKAGE_PIN AC17 IOSTANDARD LVDS_25} [get_ports {tx_data_out_p[3]}]
set_property -dict {PACKAGE_PIN AC16 IOSTANDARD LVDS_25} [get_ports {tx_data_out_n[3]}]
set_property -dict {PACKAGE_PIN W21 IOSTANDARD LVDS_25} [get_ports {tx_data_out_p[4]}]
set_property -dict {PACKAGE_PIN Y21 IOSTANDARD LVDS_25} [get_ports {tx_data_out_n[4]}]
set_property -dict {PACKAGE_PIN Y22 IOSTANDARD LVDS_25} [get_ports {tx_data_out_p[5]}]
set_property -dict {PACKAGE_PIN Y23 IOSTANDARD LVDS_25} [get_ports {tx_data_out_n[5]}]
set_property -dict {PACKAGE_PIN AE18 IOSTANDARD LVCMOS25} [get_ports enable]
set_property -dict {PACKAGE_PIN AE17 IOSTANDARD LVCMOS25} [get_ports txnrx]



#set_property  -dict {PACKAGE_PIN  AK17  IOSTANDARD LVCMOS25} [get_ports gpio_resetb]                      ; ## H31  FMC_LPC_LA28_P ok

set_property PACKAGE_PIN AC24 [get_ports spi_csn]
set_property IOSTANDARD LVCMOS25 [get_ports spi_csn]
set_property PULLUP true [get_ports spi_csn]
set_property -dict {PACKAGE_PIN AD24 IOSTANDARD LVCMOS25} [get_ports spi_clk]
#set_property  -dict {PACKAGE_PIN  AK22  IOSTANDARD LVCMOS25} [get_ports spi_mosi]                         ; ## C26  FMC_LPC_LA27_P ok
#set_property  -dict {PACKAGE_PIN  AK23  IOSTANDARD LVCMOS25} [get_ports spi_miso]                         ; ## C27  FMC_LPC_LA27_N




set_property -dict {PACKAGE_PIN AJ21 IOSTANDARD LVCMOS25} [get_ports {ctrl_in[0]}]
set_property -dict {PACKAGE_PIN AK21 IOSTANDARD LVCMOS25} [get_ports {ctrl_in[1]}]
set_property -dict {PACKAGE_PIN AJ20 IOSTANDARD LVCMOS25} [get_ports {ctrl_in[2]}]
set_property -dict {PACKAGE_PIN AK20 IOSTANDARD LVCMOS25} [get_ports {ctrl_in[3]}]
set_property -dict {PACKAGE_PIN AD21 IOSTANDARD LVCMOS25} [get_ports {ctrl_out[0]}]
set_property -dict {PACKAGE_PIN AE21 IOSTANDARD LVCMOS25} [get_ports {ctrl_out[1]}]
set_property -dict {PACKAGE_PIN AF20 IOSTANDARD LVCMOS25} [get_ports {ctrl_out[2]}]
set_property -dict {PACKAGE_PIN AG20 IOSTANDARD LVCMOS25} [get_ports {ctrl_out[3]}]
set_property -dict {PACKAGE_PIN AA22 IOSTANDARD LVCMOS25} [get_ports {ctrl_out[4]}]
set_property -dict {PACKAGE_PIN AA23 IOSTANDARD LVCMOS25} [get_ports {ctrl_out[5]}]
set_property -dict {PACKAGE_PIN AF23 IOSTANDARD LVCMOS25} [get_ports {ctrl_out[6]}]
set_property -dict {PACKAGE_PIN AF24 IOSTANDARD LVCMOS25} [get_ports {ctrl_out[7]}]

set_property -dict {PACKAGE_PIN AB21 IOSTANDARD LVCMOS25} [get_ports en_agc]
set_property -dict {PACKAGE_PIN AK17 IOSTANDARD LVCMOS25} [get_ports resetb]
set_property -dict {PACKAGE_PIN AK23 IOSTANDARD LVCMOS25} [get_ports spi_sdi]
set_property -dict {PACKAGE_PIN AK22 IOSTANDARD LVCMOS25} [get_ports spi_sdo]
set_property -dict {PACKAGE_PIN AB22 IOSTANDARD LVCMOS25} [get_ports sync_in]

# spi pmod J58

# clocks

#create_clock -name rx_clk       -period  4.00 [get_ports rx_clk_in_p]


set_property PACKAGE_PIN D9 [get_ports sclk_p]
set_property IOSTANDARD DIFF_SSTL135 [get_ports sclk_p]


set_property PACKAGE_PIN U26 [get_ports HDMI_TX_CLK_P]
set_property IOSTANDARD TMDS_33 [get_ports HDMI_TX_CLK_P]

set_property PACKAGE_PIN W29 [get_ports {HDMI_TX_P[0]}]
set_property PACKAGE_PIN T24 [get_ports {HDMI_TX_P[1]}]
set_property PACKAGE_PIN R27 [get_ports {HDMI_TX_P[2]}]

set_property IOSTANDARD TMDS_33 [get_ports {HDMI_TX_P[*]}]

set_property BITSTREAM.GENERAL.COMPRESS true [current_design]
