#!/bin/bash

mkdir -p results/fpga
source /tools/Xilinx/Vivado/2024.1/settings64.sh 
source /opt/xilinx/xrt/setup.sh

cd run/work
rm -rf sa_zcu104

# Define R and C values
R_values=(2 2 4 4 8  8 16 16 32 32)
C_values=(2 4 4 8 8 16 16 32 32 64)

for i in "${!R_values[@]}"; do
    r=${R_values[$i]}
    c=${C_values[$i]}
    outfile="../../results/fpga/${i}_${r}x${c}_time.txt"
    utilfile="../../results/fpga/${i}_${r}x${c}_util.txt"

    echo "Running iteration $i: R=$r, C=$c"

    # Overwrite hw_params.svh with new defines
    echo -e "\`define R $r\n\`define C $c" > ../../rtl/sys/hw_params.svh

    # Run Vivado in batch mode and dump both stdout and stderr
    {
        echo "=== Iteration $i $Rx$C ==="
        /usr/bin/time -v vivado -mode batch -source ../vivado_flow.tcl
    } &> "$outfile"
    cp sa_zcu104/reports/sa_zcu104_zcu104_100_utilization_report.txt "$utilfile"
done
