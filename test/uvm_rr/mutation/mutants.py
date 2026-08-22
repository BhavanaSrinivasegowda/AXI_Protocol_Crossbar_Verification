#!/usr/bin/env python3
# distributed under the mit license
# https://opensource.org/licenses/mit-license.php
#
# Line-safe mutation injector for rtl/axicb_round_robin_core.sv (REQ_NB=4
# generate block only -- the width actually exercised by FPV/props/rr_props.sv
# and test/uvm_rr). Each mutant is a small set of (line, old, new) edits.
# apply() refuses to touch the file unless the current line content exactly
# matches what's expected, so a stale line number can never silently mutate
# the wrong thing -- it just aborts.
#
# Usage:
#   ./mutants.py list
#   ./mutants.py apply <ID>
#   ./mutants.py restore

import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
RTL = os.path.normpath(os.path.join(HERE, "..", "..", "..", "rtl", "axicb_round_robin_core.sv"))
BACKUP = RTL + ".mutation_orig"

# line numbers are 1-indexed, against the unmutated rtl/axicb_round_robin_core.sv
MUTANTS = {
    "M1": {
        "desc": "Invert en-mux on grant output (grant=grant_c/grant_r swapped)",
        "edits": [
            (2771, "grant = grant_c;", "grant = grant_r;"),
            (2773, "grant = grant_r;", "grant = grant_c;"),
        ],
    },
    "M2": {
        "desc": "Drop en-guard on grant_r update (grant_r drifts while en=0)",
        "edits": [(2763, "if (en) begin", "if (1'b1) begin")],
    },
    "M3": {
        "desc": "Wrong-requester grant on masked path (masked[1] grants req2 not req1)",
        "edits": [(187, "else if (masked[1]) grant_c = 4'd2;", "else if (masked[1]) grant_c = 4'd4;")],
    },
    "M4": {
        "desc": "Wrong-requester grant on unmasked path (req[2] grants req1 not req2)",
        "edits": [(196, "else if (req[2]) grant_c = 4'd4;", "else if (req[2]) grant_c = 4'd2;")],
    },
    "M5": {
        "desc": "Remove 'else' before masked[1] check -> possible multi-hot grant",
        "edits": [(187, "else if (masked[1]) grant_c = 4'd2;", "if      (masked[1]) grant_c = 4'd2;")],
    },
    "M6": {
        "desc": "Branch on req instead of masked -> starvation when masked=0,req!=0",
        "edits": [(185, "if (|masked) begin", "if (|req) begin")],
    },
    "M7": {
        "desc": "Off-by-one mask rotation after grant[0] -> skips requester 1",
        "edits": [(211, "if      (grant[0]) mask <= 4'b1110;", "if      (grant[0]) mask <= 4'b1100;")],
    },
    "M8": {
        "desc": "Sync reset (srst) no longer clears mask",
        "edits": [(207, "end else if (srst) begin", "end else if (1'b0) begin")],
    },
}


def read_lines():
    with open(RTL) as f:
        return f.readlines()


def apply(mid):
    if mid not in MUTANTS:
        sys.exit(f"unknown mutant {mid!r} -- known: {', '.join(MUTANTS)}")
    if os.path.exists(BACKUP):
        sys.exit(f"backup {BACKUP} already exists -- run './mutants.py restore' first")

    shutil.copy2(RTL, BACKUP)
    lines = read_lines()

    for lineno, old, new in MUTANTS[mid]["edits"]:
        idx = lineno - 1
        actual = lines[idx].strip()
        if actual != old:
            shutil.copy2(BACKUP, RTL)
            os.remove(BACKUP)
            sys.exit(
                f"line {lineno} mismatch: expected {old!r}, got {actual!r} "
                "-- aborted, RTL left untouched. The file has likely drifted "
                "from what these mutants were written against; re-derive the "
                "line numbers before retrying."
            )
        indent = lines[idx][: len(lines[idx]) - len(lines[idx].lstrip())]
        lines[idx] = indent + new + "\n"

    with open(RTL, "w") as f:
        f.writelines(lines)
    print(f"applied {mid}: {MUTANTS[mid]['desc']}")


def restore():
    if not os.path.exists(BACKUP):
        sys.exit("no backup found -- nothing to restore")
    shutil.copy2(BACKUP, RTL)
    os.remove(BACKUP)
    print("restored original RTL")


def list_mutants():
    for k, v in MUTANTS.items():
        print(f"{k}: {v['desc']}")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "apply" and len(sys.argv) > 2:
        apply(sys.argv[2])
    elif cmd == "restore":
        restore()
    elif cmd == "list":
        list_mutants()
    else:
        sys.exit("usage: mutants.py {list|apply <ID>|restore}")
