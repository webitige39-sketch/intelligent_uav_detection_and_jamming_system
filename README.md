# Intelligent UAV Detection and Jamming System

无人机智能侦察干扰系统 FPGA / PS 代码。

## 硬件和工具

- FPGA：AMD/Xilinx Zynq-7000，`xc7z100ffv900-1`（主工程 XPR 配置）。
- 开发板：技术文档标注 MLK-H3-CZ08-7100；XPR 未设置 BoardPart。
- 射频模块：AD9361。
- 原工程使用 Vivado / Vitis 2021.1。优先使用同版本打开；未验证跨版本升级。
- 主工程：`mult_freq_jam_dma_0711.xpr`；顶层：`system_wrapper_dma`。

## 目录

| 路径 | 内容 |
| --- | --- |
| `code_ad9361/` | AD9361 接口、SPI 与初始化逻辑 |
| `code_aim/` | 信号检测、FFT、相关与 CFAR 相关逻辑 |
| `code_noise/` | 噪声及波形逻辑、COE 初始化数据 |
| `mult_freq_jam_dma_0711.srcs/` | 主工程 RTL、XDC、Block Design 和 IP 配置 |
| `soc_sdk/` | PS 应用、平台配置、BSP 与 lwIP 源码 |
| `hardware/` | 原工程已有 BIT、LTX 和 XSA |
| `reports/` | 原工程已有综合/实现资源和时序报告 |
| `data/` | 原工程 ILA 导出数据 |
| `build/` | PL 构建脚本、源码校验清单和校验工具 |

保留原文件命名以保持现有工程引用和软件 include 兼容。包含原工程已有辅助源文件和备用平台；主 PS 应用是 `soc_sdk/7100_eth_test_1`，对应平台为 `soc_sdk/7100_eth_test`。

## PL 构建

建议解压到短路径，例如 `E:/uav_fpga_source`，避免 Windows 路径长度限制。

在 Vivado 2021.1 命令行环境中运行：

```text
vivado -mode batch -source build/build_pl.tcl
```

脚本打开主 XPR、重新生成 IP/BD 输出、执行综合和实现，并输出报告及 XSA。也可以在 GUI 打开主 XPR 完成同样步骤。首次构建可能需要较长时间；本次整理只做了文件完整性检查，没有重新综合、实现或上板，因此不将脚本标为已通过构建验证。

## PS 构建与运行

1. 在 Vitis 2021.1 中选择新的短路径 workspace，导入 `soc_sdk` 中的平台、应用和系统工程。
2. 使用 `hardware/system_wrapper_dma.xsa` 更新 `7100_eth_test` 平台；若 PL 已重建，应改用新的 `build/output/system_wrapper_dma.xsa`。
3. 原平台配置含开发电脑的工具安装路径和绝对路径，在本机重新选择硬件文件和工具路径。
4. BSP 的 lwIP 源码有本地修改。重新生成 BSP 之前保存并比对 `soc_sdk/7100_eth_test/ps7_cortexa9_0/standalone_domain/bsp/ps7_cortexa9_0/libsrc/lwip211_v1_5/src`，避免覆盖补丁。备份目录 `src_before_lwip211_v2_0_patch` 同时保留。
5. 构建平台、BSP 和 `7100_eth_test_1` 应用；具体 TCP 协议见应用中的 `protocol.h`、`tcp_client.c` 和随附 README。
6. 下载 PL 的 BIT；使用 ILA 时选择同一实现生成的 LTX；然后下载并运行匹配的 ELF。原工程已有文件可在 `hardware/` 和应用的 `Debug/` 下找到。

## 验证状态与范围

- `reports/` 是随原工程提供的已有结果，不是本次重新运行生成。
- 现有时序报告有未约束端点及无时钟检查项，应在完整约束审查后再宣称时序收敛。
- `README_NEW_PROJECT.md` 是原工程说明，其中 DMA 数据源与实测范围的描述应结合当前 RTL 和实际板级测试核对。
- 当前代码包不含未提供的 Qt 上位机、CNN 训练/推理代码或模型权重，不能仅凭技术报告认定这些代码已包含。
- 技术报告、技能包和大模型协作记录由参赛队单独准备，本仓库不代填实验结论。

## 文件校验

在仓库根目录运行 `python build/verify_sources.py`，检查随包源码是否与整理时的 SHA-256 清单一致，并检查 XPR 直接引用的文件是否齐全。

## 第三方代码

保留 Xilinx/AMD、lwIP 等第三方文件原有的版权和许可声明。项目自有源码的开源许可证应由作者确定后补充；本次整理未给第三方代码重新授权。
