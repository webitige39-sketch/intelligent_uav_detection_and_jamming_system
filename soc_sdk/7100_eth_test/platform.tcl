# 
# Usage: To re-create this platform project launch xsct with below options.
# xsct E:\FPGA_project\09_daq7606_lwip_tcp_dma\soc_sdk_0711\7100_eth_test\platform.tcl
# 
# OR launch xsct and run below command.
# source E:\FPGA_project\09_daq7606_lwip_tcp_dma\soc_sdk_0711\7100_eth_test\platform.tcl
# 
# To create the platform in a different location, modify the -out option of "platform create" command.
# -out option specifies the output directory of the platform project.

platform create -name {7100_eth_test}\
-hw {E:\FPGA_project\09_daq7606_lwip_tcp_dma\soc_hw\system_wrapper.xsa}\
-proc {ps7_cortexa9_0} -os {standalone} -out {E:/FPGA_project/09_daq7606_lwip_tcp_dma/soc_sdk_0711}

platform write
platform generate -domains 
platform active {7100_eth_test}
domain active {zynq_fsbl}
bsp reload
bsp setlib -name lwip211 -ver 1.5
bsp write
bsp reload
catch {bsp regenerate}
domain active {standalone_domain}
bsp reload
bsp setlib -name lwip211 -ver 1.5
bsp write
bsp reload
catch {bsp regenerate}
platform generate
platform generate
platform generate -domains standalone_domain,zynq_fsbl 
platform clean
platform generate
