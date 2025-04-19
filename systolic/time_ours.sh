#!/bin/bash
out_dir="results/ours"

source /tools/Xilinx/Vivado/2024.1/settings64.sh 
source /opt/xilinx/xrt/setup.sh

mkdir -p $out_dir

# Arrays of R and C values
R_values=(2 2 4 4 8  8 16 16 32 32)
C_values=(2 4 4 8 8 16 16 32 32 64)

# Loop through each pair
for i in "${!R_values[@]}"; do
    r=${R_values[$i]}
    c=${C_values[$i]}
    k=$((r + c))

    outfile="${out_dir}/${i}_${r}x${c}.txt"

    echo "Running iteration $i: R=$r, C=$c, K=$k"
    {
        echo "=== Iteration $i ==="
        echo "R = $r, C = $c, K = $k"
        echo ""
        make clean
        /usr/bin/time -v make xsim R=$r C=$c K=$k VALID_PROB=1000 READY_PROB=1000
    } &> "$outfile"
done
