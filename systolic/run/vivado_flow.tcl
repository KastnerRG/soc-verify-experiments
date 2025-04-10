
set PROJECT_NAME sa_zcu104
set RTL_DIR      ../../rtl

set CONFIG_BASEADDR 0x00B0000000
set FREQ         100
set AXI_WIDTH    128

source ../../tcl/fpga/zcu104.tcl
source ../../tcl/fpga/vivado.tcl