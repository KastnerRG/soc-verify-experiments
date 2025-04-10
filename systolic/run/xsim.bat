set XIL_PATH=F:\Xilinx\Vivado\2022.2\bin
set TB_MODULE=top_tb

set R=8
set C=4
set K=16
set VALID_PROB=1
set READY_PROB=50

SETLOCAL EnableDelayedExpansion
mkdir "work\data"
set DIR_BACKSLASH="%CD%/work/data/"
set "DIR=%DIR_BACKSLASH:\=/%"
call python golden.py --R %R% --K %K% --C %C% --DIR %DIR% || exit /b !ERRORLEVEL!

cd work

call %XIL_PATH%\xsc ../../c/sim.c --gcc_compile_options -I%DIR_BACKSLASH% --gcc_compile_options -DSIM --gcc_compile_options "-DDIR=%DIR%" || exit /b !ERRORLEVEL!
call %XIL_PATH%\xvlog -sv -d "DIR=%DIR%" -d "R=%R%" -d "C=%C%" -d "VALID_PROB=%VALID_PROB%" -d "READY_PROB=%READY_PROB%"  -f ../sources.txt -i ../ || exit /b !ERRORLEVEL!
call %XIL_PATH%\xelab %TB_MODULE% --snapshot %TB_MODULE% -log elaborate.log --debug typical -sv_lib dpi || exit /b !ERRORLEVEL!
call %XIL_PATH%\xsim %TB_MODULE% --tclbatch ../xsim_cfg.tcl