PS source package: Mode1/Mode2 event DMA upload + Mode3 GPIO control
====================================================================

AXI-GPIO mapping:
  axi_gpio_mode3_cfg0 channel 1:
    bit[15:0]  = DIV_CNT
    bit[19:16] = sel_jam
    bit[29]    = stream_enable
    bit[30]    = stream_mode: 0=Mode2, 1=Mode1
    bit[31]    = configuration update toggle
  axi_gpio_mode3_cfg0 channel 2:
    bit[31:0]  = AIM_TIME
  axi_gpio_mode3_thred channel 1:
    bit[31:0]  = Thred

START sequence:
  1. Set bit29/bit30.
  2. Arm AXI DMA S2MM with the mode-specific byte count.
  3. Pulse user_start.
  4. Wait for a PL detection event and DMA completion.

Mode3 parameter writes preserve bit29 and bit30, so changing jammer parameters does not stop or switch the active stream mode.
