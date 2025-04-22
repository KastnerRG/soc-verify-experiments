#!/usr/bin/env bash
# generate_csv.sh  – build results.csv from *_time.txt and *_util.txt
set -euo pipefail

DIR="results/fpga"
cd "$DIR"

# Columns, in order
combos=(2x2 2x4 4x4 4x8 8x8 8x16 16x16 16x32 32x32 32x64)

# Metrics
declare -A USER SYS WALL RSS LUT FF DSP

for combo in "${combos[@]}"; do
    time_file=$(ls -1 *_${combo}_time.txt 2>/dev/null | head -n1 || true)
    util_file=$(ls -1 *_${combo}_util.txt 2>/dev/null | head -n1 || true)

    # ── *_time.txt ───────────────────────────────────────────────────
    if [[ -f $time_file ]]; then
        USER[$combo]=$(grep -m1 "User time (seconds)"        "$time_file" | awk -F': *' '{print $2}' | tr -d '\r')
        SYS[$combo]=$(grep  -m1 "System time (seconds)"      "$time_file" | awk -F': *' '{print $2}' | tr -d '\r')
        WALL[$combo]=$(grep -m1 "Elapsed (wall clock)"       "$time_file" | awk '{print $NF}'         | tr -d '\r')
        RSS[$combo]=$(grep  -m1 "Maximum resident set size"  "$time_file" | awk -F': *' '{print $2}' | tr -d '\r')
    fi

    # ── *_util.txt ─────────────────────────────────────────────────-
    if [[ -f $util_file ]]; then
        LUT[$combo]=$(grep -m1 "CLB LUTs"        "$util_file" | awk -F'|' '{gsub(/ /,"",$3); print $3}' | tr -d '\r')
        FF[$combo]=$(grep  -m1 "CLB Registers"   "$util_file" | awk -F'|' '{gsub(/ /,"",$3); print $3}' | tr -d '\r')
        DSP[$combo]=$(grep -m1 "|[[:space:]]*DSP" "$util_file" | awk -F'|' '{gsub(/ /,"",$3); print $3}' | tr -d '\r')
    fi
done

# ── Emit CSV ────────────────────────────────────────────────────────
out="../fpga.csv"
{
    printf ",%s\n" "$(IFS=,; echo "${combos[*]}")"

    printf "User Time,";                     for c in "${combos[@]}"; do printf "%s," "${USER[$c]:-}"; done; echo
    printf "Sys Time,";                      for c in "${combos[@]}"; do printf "%s," "${SYS[$c]:-}";  done; echo
    printf "Wall Clock Time,";               for c in "${combos[@]}"; do printf "%s," "${WALL[$c]:-}"; done; echo
    printf "Maximum resident set size (kB),";for c in "${combos[@]}"; do printf "%s," "${RSS[$c]:-}";  done; echo
    printf "LUTs,";                          for c in "${combos[@]}"; do printf "%s," "${LUT[$c]:-}";  done; echo
    printf "FFs,";                           for c in "${combos[@]}"; do printf "%s," "${FF[$c]:-}";   done; echo
    printf "DSPs,";                          for c in "${combos[@]}"; do printf "%s," "${DSP[$c]:-}";  done; echo
} | sed 's/,$//' > "$out"

echo "✓  CSV written to $(realpath "$out")"
