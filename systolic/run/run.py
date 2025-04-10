import numpy as np
import subprocess
import os

# Matrix sizes
R=2
C=2
K=6

# Widths
WXK=8
WY=32

# Latency of mul & acc
LM=1
LA=1

# AXI Stream Control
P_VALID=1
P_READY=1
NUM_EXP=100

sources = [
    '../rtl/mac.sv',
    '../rtl/tri_buffer.sv',
    '../rtl/n_delay.sv',
    '../rtl/axis_sa.sv', 
    '../tb/axis_tb.sv',
    '../py_tb.sv',
]

# create directories: vectors, build, run
os.makedirs('vectors', exist_ok=True)
os.makedirs('build', exist_ok=True)
os.makedirs('run', exist_ok=True)

# compile with verilator
cmd = 'verilator --binary -j 0 --trace -O3 --Wno-BLKANDNBLK --top py_tb -Mdir build ' 
cmd += f'-DR={R} -DC={C} -DK={K} -DWXK={WXK} -DWY={WY} '
cmd += f'-DLM={LM} -DLA={LA} -DP_VALID={P_VALID} -DP_READY={P_READY} '
assert subprocess.run(cmd.split() + sources).returncode == 0


for n in range(NUM_EXP):

    # Generate random x and k matrices
    MIN=-2**(WXK-1)
    MAX=2**(WXK-1)-1
    xm = np.random.randint(MIN, MAX, (R, K))
    km = np.random.randint(MIN, MAX, (K, C))
    y_exp = np.matmul(xm, km)

    # Write x,k to file
    with open('vectors/xk.txt', 'w') as f:
        for k in range(K):
            for r in range(R):
                f.write(str(xm[r, k]) + '\n')
            for c in range(C):
                f.write(str(km[k, c]) + '\n')
                
    # Simulate
    assert subprocess.run(['../build/Vpy_tb'], cwd='run').returncode == 0

    # read y.txt into y in row_major order
    ym = np.zeros((R, C), dtype=np.int32)
    with open('vectors/y.txt', 'r') as f:
        for c in range(C):
            for r in range(R):
                ym[r, c] = int(f.readline())

    error = np.sum(np.abs(ym-y_exp))
    
    print(f'{n}) Error: {error}')
    assert error == 0, print(f'ym:\n{ym}\ny_exp:\n{y_exp}')
