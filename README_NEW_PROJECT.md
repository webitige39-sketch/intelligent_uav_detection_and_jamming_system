# 旧工程副本：PS + DMA + lwIP

本目录由 `mult_freq_jam_test_0113_beifen_0623` 独立复制而来；原工程、现工程和原 lwIP 库均未修改。

## 交付文件

- `hardware/system_wrapper_dma.bit`：最终 PL 配置文件。
- `hardware/system_wrapper_dma.ltx`：与上述 bit 同一次实现生成的 ILA probes 文件。
- `hardware/system_wrapper_dma.xsa`：包含 bit 的硬件平台文件。
- `soc_sdk/7100_eth_test_1/Debug/7100_eth_test_1.elf`：使用新 XSA/BSP 重建的 TCP/DMA 程序。

下载 PL 时必须同时选择 `hardware/system_wrapper_dma.bit` 与同目录的
`system_wrapper_dma.ltx`。PS 下载 ELF 只启动软件，不能替代 PL bitstream 下载。

## 保留与新增内容

- AD9361、SPI 初始化和旧射频收发逻辑保留自验证通过的旧工程。
- 新增精简 Block Design：PS7、128-bit S2MM AXI DMA、4 个 AXI GPIO、DMA 中断。
- HDMI、VDMA、HDMI 自定义 IP 未纳入本工程。
- 旧 VIO 参数输出已替换为 PS GPIO，并通过 CDC 后进入 40 MHz 与 200 MHz 域。
- `pl_rstn` 不连接到 AD9361 初始化/复位状态机，PS 的复位和配置不会重启 SPI 初始化。

## GPIO 参数格式

`mode3_cfg0`：

- `[15:0]`：`DIV_CNT`
- `[19:16]`：`sel_jam`
- `[29]`：DMA 数据输出使能
- `[30]`：DMA 示例数据模式选择
- `[31]`：配置更新翻转位；PS 应先写 `AIM_TIME`、阈值和 cfg0 的低位，最后翻转此位。

DMA/GPIO 地址保持与现有 PS 程序一致：DMA `0x40400000`，GPIO
`0x41200000` 到 `0x41230000`。

## lwIP

新副本的 `soc_sdk/7100_eth_test` 平台已更新为本目录的 XSA。其 BSP 中的
`lwip211_v1_5/src` 已用你指定的 `lwip211_v2_0/src` 替换；自动生成的原 src
保留为同目录 `src_before_lwip211_v2_0_patch`，可随时回退。Vitis 重新打开
工作区后可识别更新后的库和平台。

## 验证结果

- PL 综合成功。
- 实现、DRC、bitgen 成功：0 错误、0 严重警告。
- 新 XSA 已导出。
- BSP 与 `7100_eth_test_1.elf` 已清理后重新编译成功。

当前 DMA 采用独立的 `uav_mode_axis_src_128` 示例数据源，目的是先稳定验证
PS DMA、TCP、GPIO 与 Qt 协议链路；它不等同于将实时 ADC IQ 直接写入 DDR。
