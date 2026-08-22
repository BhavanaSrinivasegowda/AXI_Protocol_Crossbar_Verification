# Mutation testing summary

| Mutant | Description | UVM | FPV |
|---|---|---|---|
| M1 | Invert en-mux on grant output (grant=grant_c/grant_r swapped) | KILLED (UVM_ERROR=425, scoreboard mismatches=449) | skipped |
| M2 | Drop en-guard on grant_r update (grant_r drifts while en=0) | KILLED (UVM_ERROR=3, scoreboard mismatches=2) | skipped |
| M3 | Wrong-requester grant on masked path (masked[1] grants req2 not req1) | KILLED (UVM_ERROR=170, scoreboard mismatches=182) | skipped |
| M4 | Wrong-requester grant on unmasked path (req[2] grants req1 not req2) | KILLED (UVM_ERROR=9, scoreboard mismatches=9) | skipped |
| M5 | Remove 'else' before masked[1] check -> possible multi-hot grant | KILLED (UVM_ERROR=115, scoreboard mismatches=124) | skipped |
| M6 | Branch on req instead of masked -> starvation when masked=0,req!=0 | KILLED (UVM_ERROR=475, scoreboard mismatches=509) | skipped |
| M7 | Off-by-one mask rotation after grant[0] -> skips requester 1 | KILLED (UVM_ERROR=85, scoreboard mismatches=95) | skipped |
| M8 | Sync reset (srst) no longer clears mask | KILLED (UVM_ERROR=0, scoreboard mismatches=1) | skipped |
