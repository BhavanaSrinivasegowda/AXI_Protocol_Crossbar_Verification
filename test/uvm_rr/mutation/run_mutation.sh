#!/usr/bin/env bash
# distributed under the mit license
# https://opensource.org/licenses/mit-license.php
#
# Mutation-testing sweep for axicb_round_robin_core.sv: for each mutant
# defined in mutants.py, injects it into the RTL, runs the full 5-test UVM
# regression (lean -- no waveform/coverage dump, just PASS/FAIL and
# scoreboard mismatch count) and, unless --uvm-only is given, a JasperGold
# proof of FPV/props/rr_props.sv, then reverts the RTL before moving on.
#
# A survived mutant (neither UVM nor FPV flags it) is the interesting
# result: it's either a real hole in the checkers, or a change with no
# observable functional effect worth understanding either way.
#
# Usage:
#   ./run_mutation.sh                run all 8 mutants, UVM + FPV
#   ./run_mutation.sh --uvm-only     skip JasperGold (faster)
#   ./run_mutation.sh M3 M7          run only the named mutants
#   ./run_mutation.sh --uvm-only M2  combine flag + subset
#
# Requires QuestaSim (vlib/vlog/vsim) on PATH always, and JasperGold (jg)
# on PATH unless --uvm-only is passed. Safe to Ctrl-C: a trap restores the
# original RTL on any exit.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UVM_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"           # test/uvm_rr
ROOT_DIR="$(cd "$UVM_DIR/../.." && pwd)"          # project root
FPV_TCL_DIR="$ROOT_DIR/FPV/tcl"
RTL="$ROOT_DIR/rtl/axicb_round_robin_core.sv"
RESULT_DIR="$SCRIPT_DIR/results"
mkdir -p "$RESULT_DIR"

MUTATE="$SCRIPT_DIR/mutants.py"
ALL_MUTANTS=(M1 M2 M3 M4 M5 M6 M7 M8)

UVM_ONLY=0
MUTANTS_TO_RUN=()
for arg in "$@"; do
    if [[ "$arg" == "--uvm-only" ]]; then
        UVM_ONLY=1
    else
        MUTANTS_TO_RUN+=("$arg")
    fi
done
[[ ${#MUTANTS_TO_RUN[@]} -eq 0 ]] && MUTANTS_TO_RUN=("${ALL_MUTANTS[@]}")

cleanup() {
    python3 "$MUTATE" restore 2>/dev/null || true
}
trap cleanup EXIT

SUMMARY="$RESULT_DIR/summary.md"
{
    echo "# Mutation testing summary"
    echo
    echo "| Mutant | Description | UVM | FPV |"
    echo "|---|---|---|---|"
} > "$SUMMARY"

run_uvm() {
    local tag=$1
    local log="$RESULT_DIR/${tag}_uvm.log"
    : > "$log"

    pushd "$UVM_DIR" >/dev/null
    vlib work >/dev/null 2>&1 || true
    vmap work work >/dev/null
    vlog -sv +acc "$RTL" >> "$log" 2>&1
    vlog -sv +acc rr_if.sv rr_pkg.sv rr_tb_top.sv >> "$log" 2>&1

    for t in rr_reset_test rr_walking_one_test rr_all_active_test rr_srst_test rr_random_test; do
        echo "--- $t ---" >> "$log"
        vsim -c work.rr_tb_top +UVM_TESTNAME="$t" +UVM_VERBOSITY=UVM_MEDIUM \
            -do "run -all; quit -f" >> "$log" 2>&1 || true
    done
    popd >/dev/null

    local errors mismatches
    errors=$(awk '/UVM_ERROR :/{s+=$NF} END{print s+0}' "$log")
    mismatches=$(grep -c "grant mismatch" "$log" || true)

    if [[ "$errors" != "0" || "$mismatches" != "0" ]]; then
        echo "KILLED (UVM_ERROR=$errors, scoreboard mismatches=$mismatches)"
    else
        echo "SURVIVED"
    fi
}

run_fpv() {
    local tag=$1
    local log="$RESULT_DIR/${tag}_fpv.log"
    local jg_proj="$RESULT_DIR/jgproject_${tag}"

    pushd "$FPV_TCL_DIR" >/dev/null
    MUTATION_TAG="$tag" jg -batch -label "mut_${tag}" -proj "$jg_proj" \
        rr_fpv_mutation.tcl > "$log" 2>&1 || true
    popd >/dev/null
    rm -rf "$jg_proj"

    if grep -q "MUTATION_RESULT: 0 failing" "$log"; then
        echo "SURVIVED"
    elif grep -q "MUTATION_RESULT:" "$log"; then
        echo "KILLED ($(grep 'MUTATION_RESULT:' "$log" | tail -1 | cut -d' ' -f2-4))"
    else
        echo "ERROR (see $log)"
    fi
}

for m in "${MUTANTS_TO_RUN[@]}"; do
    desc=$(python3 "$MUTATE" list | grep "^$m:" | cut -d: -f2- | sed 's/^ //')
    echo "=== $m: $desc ==="

    python3 "$MUTATE" apply "$m"

    uvm_result=$(run_uvm "$m")
    echo "  UVM: $uvm_result"

    if [[ $UVM_ONLY -eq 0 ]]; then
        fpv_result=$(run_fpv "$m")
        echo "  FPV: $fpv_result"
    else
        fpv_result="skipped"
    fi

    python3 "$MUTATE" restore

    echo "| $m | $desc | $uvm_result | $fpv_result |" >> "$SUMMARY"
done

trap - EXIT

echo
echo "Done. Summary written to $SUMMARY"
echo
cat "$SUMMARY"
