#!/bin/bash
shopt -s expand_aliases
source ~/.bash_aliases
x24

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/home/a.gnaneswaran/install/miniconda/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/home/a.gnaneswaran/install/miniconda/etc/profile.d/conda.sh" ]; then
        . "/home/a.gnaneswaran/install/miniconda/etc/profile.d/conda.sh"
    else
        export PATH="/home/a.gnaneswaran/install/miniconda/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

conda activate dsf
python -m pytest -s ../param_test.py
