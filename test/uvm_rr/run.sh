#!/usr/bin/env bash
# distributed under the mit license
# https://opensource.org/licenses/mit-license.php
#
# Usage:
#   ./run.sh                            run the full test list (batch)
#   ./run.sh <test_name>                 run a single UVM test (batch)
#   ./run.sh <test_name> <seed>          run a single UVM test with a fixed seed (batch)
#   ./run.sh --gui <test_name> [seed]    run a single UVM test interactively in the
#                                         Questa GUI, with waves preloaded
#
# Every batch run writes, per test, into logs/:
#   <test>_<seed>.log    full transcript (grep for UVM_ERROR/UVM_FATAL)
#   <test>_<seed>.wlf    waveform database -> view later with:
#                            vsim -view logs/<test>_<seed>.wlf -do "add wave -r /*"
#   <test>_<seed>.ucdb   functional + code coverage database for that run
#
# After a batch run it also prints a PASS/FAIL summary, merges all the .ucdb
# files in logs/ into logs/merged.ucdb, and writes logs/coverage_summary.txt.
# Open the merged coverage interactively with:
#   vsim -viewcov logs/merged.ucdb
#
# UVM_VERBOSITY can be overridden via env var, e.g.:
#   UVM_VERBOSITY=UVM_HIGH ./run.sh rr_random_test

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

RTL_DIR=../../rtl
DUT=$RTL_DIR/axicb_round_robin_core.sv
LOG_DIR=logs

TESTS=(
    rr_reset_test
    rr_walking_one_test
    rr_all_active_test
    rr_srst_test
    rr_random_test
)

UVM_VERBOSITY=${UVM_VERBOSITY:-UVM_MEDIUM}
GUI=0

if [[ "${1:-}" == "--gui" || "${1:-}" == "-g" ]]; then
    GUI=1
    shift
    if [[ $# -lt 1 ]]; then
        echo "Error: --gui requires a <test_name> (e.g. ./run.sh --gui rr_random_test [seed])" >&2
        exit 1
    fi
fi

mkdir -p "$LOG_DIR"

vlib work
vmap work work

# DUT compiled separately, instrumented for code coverage (branch/condition/statement/toggle)
vlog -sv +acc +cover=bcst \
    "$DUT"

# testbench, not instrumented (covergroup-based functional coverage still collected)
vlog -sv +acc \
    rr_if.sv \
    rr_pkg.sv \
    rr_tb_top.sv

declare -A RESULT

run_one() {
    local test=$1
    local seed=${2:-random}
    local tag="${test}_${seed}"
    local log="$LOG_DIR/${tag}.log"
    local wlf="$LOG_DIR/${tag}.wlf"
    local ucdb="$LOG_DIR/${tag}.ucdb"

    echo "=== Running $test (seed=$seed) ==="

    if [[ $GUI -eq 1 ]]; then
        vsim work.rr_tb_top -coverage \
            +UVM_TESTNAME="$test" +UVM_VERBOSITY=$UVM_VERBOSITY -sv_seed "$seed" \
            -l "$log" -wlf "$wlf" \
            -do "log -r /*; add wave -r /*; run -all; coverage save $ucdb"
        return
    fi

    vsim -c work.rr_tb_top -coverage \
        +UVM_TESTNAME="$test" +UVM_VERBOSITY=$UVM_VERBOSITY -sv_seed "$seed" \
        -l "$log" -wlf "$wlf" \
        -do "log -r /*; run -all; coverage save $ucdb; quit -f"

    local errors fatals
    if grep -q "UVM Report Summary" "$log"; then
        errors=$(awk '/UVM_ERROR :/{c=$NF} END{print c+0}' "$log")
        fatals=$(awk '/UVM_FATAL :/{c=$NF} END{print c+0}' "$log")
    else
        # no summary block found (e.g. a $fatal / crash cut the run short) -> treat as failure
        errors=1
        fatals=1
    fi

    if [[ "$errors" == "0" && "$fatals" == "0" ]]; then
        RESULT[$tag]="PASS"
    else
        RESULT[$tag]="FAIL (errors=$errors fatals=$fatals) -- see $log"
    fi
}

if [[ $# -ge 1 ]]; then
    run_one "$1" "${2:-random}"
else
    for t in "${TESTS[@]}"; do
        run_one "$t"
    done
fi

if [[ $GUI -eq 0 ]]; then
    echo
    echo "=== Summary ==="
    for tag in "${!RESULT[@]}"; do
        printf '%-40s %s\n' "$tag" "${RESULT[$tag]}"
    done

    ucdbs=()
    while IFS= read -r -d '' f; do ucdbs+=("$f"); done \
        < <(find "$LOG_DIR" -maxdepth 1 -name '*.ucdb' ! -name 'merged.ucdb' -print0)

    if [[ ${#ucdbs[@]} -gt 0 ]]; then
        echo
        echo "=== Merging coverage ==="
        vcover merge "$LOG_DIR/merged.ucdb" "${ucdbs[@]}"
        vcover report -details -all "$LOG_DIR/merged.ucdb" > "$LOG_DIR/coverage_summary.txt"
        echo "Coverage summary written to: $LOG_DIR/coverage_summary.txt"
        echo "Open merged coverage in the GUI with: vsim -viewcov $LOG_DIR/merged.ucdb"
    fi
fi
