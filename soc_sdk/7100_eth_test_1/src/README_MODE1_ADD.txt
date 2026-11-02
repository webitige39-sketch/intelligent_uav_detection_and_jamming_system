UAV PS参考源码：Mode1真实事件DMA + Mode2事件快照DMA + Mode3 GPIO
================================================================

命令：
  START Mode2: 0xAA55FFA0
  STOP  Mode2: 0xAA55FFB1
  START Mode1: 0xAA55FFA1
  STOP  Mode1: 0xAA55FFB2
  Mode3 Ctrl : 0xAA55FFC3

Mode1：
  数据源：PL真实侦察/干扰链路 -> AXI DMA S2MM -> DDR -> TCP
  Header: 48 bytes, magic='MOD1', mode=1
  Payload: RX IQ 1024点 + 当前sel_jam最终输出的JAM IQ 4096点
  Payload bytes: 20480
  没有有效检测事件时DMA保持等待；不是错误。

Mode2：
  数据源：PL固定Profile 0后的事件快照 -> AXI DMA S2MM -> DDR -> TCP
  Payload: 256x1024复数IQ，1048576 bytes
  默认32行预触发、224行后触发。

Mode3：
  Qt参数通过PS AXI GPIO送PL，bit31更新toggle保证多位参数在PL一次锁存。

本版本已经删除旧的uav_generate_mode1_payload()假数据路径。
替换Vitis应用src前，请保留已经修好的RTL8211FDI/lwIP BSP。
