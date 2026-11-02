本目录是三模式合并后的PS参考源码。

替换方法：
1. 先备份当前Vitis应用src。
2. 将本目录源码与当前已调通的PHY/lwIP工程合并；不要覆盖已修好的RTL8211FDI BSP。
3. 确认xparameters.h中存在Mode3两个AXI GPIO和DMA设备ID。
4. Clean Project / Build Project后下载运行。

事件DMA的正常表现：
- START后先打印“DMA frame started”；
- 没有正检测时会周期打印INFO waiting for detected event；
- 检测发生并形成完整窗口后打印DMA done和CRC；
- 这类等待不是TVALID/TLAST错误。

若检测已明确发生但DMA一直不完成，再检查：
- cfg0[29]/[30]；
- user_start脉冲；
- AXI TVALID/TREADY/TLAST；
- Mode1 20480 Byte、Mode2 1048576 Byte长度；
- AXI DMA S2MM宽度128 bit。
