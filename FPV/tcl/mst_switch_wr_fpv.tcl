clear -all


# ==============================================================================
# USER TOGGLE - set to 1 for Pass 1 (fast), 0 for Pass 2 (full)
# ==============================================================================
set BBOX_FIFO 1


# ==============================================================================
# 1. ANALYSIS
#    All files analyzed in both passes.
#    FIFO black-boxing is handled at elaborate time via -bbox_m.
# ==============================================================================
analyze -sv12 \
    ../../rtl/axicb_round_robin_core.sv \
    ../../rtl/axicb_round_robin.sv \
    ../../rtl/axicb_scfifo_ram.sv \
    ../../rtl/axicb_scfifo_regfile.sv \
    ../../rtl/axicb_scfifo.sv \
    ../../rtl/axicb_mst_switch_wr.sv \
    ../props/mst_switch_wr_props.sv \
    ../bind1/mst_switch_wr_bind.sv \
    ../tb/mst_switch_wr_fpv_top.sv


# ==============================================================================
# 2. COVERAGE INIT (must be before elaborate)
# ==============================================================================
check_cov -init -model branch
check_cov -init -model statement


# ==============================================================================
# 3. ELABORATE
#    PASS 1 (BBOX_FIFO=1):
#      -bbox_m axicb_scfifo  : black-boxes the FIFO, removing its 256-entry
#                              RAM state space from the proof.
#      -parameter FIFO_OPEN 0: tells props to force srst=0 (A18 Pass1 branch)
#                              and to NOT elaborate the FIFO-dependent cover
#                              properties (GEN_COV_PASS2 generate block).
#                              This eliminates all unreachable cover points
#                              at the source rather than disabling them in TCL.
#
#    PASS 2 (BBOX_FIFO=0):
#      No bbox. Full FIFO state space included.
#      -parameter FIFO_OPEN 1: tells props to allow srst (A18 Pass2 branch,
#                              rare 1-2 cycle bursts) and to elaborate all
#                              FIFO-dependent cover properties. Every
#                              precondition becomes genuinely reachable.
# ==============================================================================
if { $BBOX_FIFO == 1 } {
    puts "INFO: PASS 1 - axicb_scfifo black-boxed, FIFO_OPEN=0"
    elaborate \
        -top        mst_switch_wr_fpv_top \
        -bbox_m     axicb_scfifo \
        -parameter  AXI_ID_W            8   \
        -parameter  AXI_DATA_W          8   \
        -parameter  MST_NB              4   \
        -parameter  NUM_PRIORITY_LVL    4   \
        -parameter  TIMEOUT_ENABLE      0   \
        -parameter  PRIORITY_W          2   \
        -parameter  AWCH_W              8   \
        -parameter  WCH_W               8   \
        -parameter  BCH_W               8   \
        -parameter  FIFO_OPEN           0
} else {
    puts "INFO: PASS 2 - full FIFO state space, FIFO_OPEN=1"
    elaborate \
        -top        mst_switch_wr_fpv_top \
        -parameter  AXI_ID_W            8   \
        -parameter  AXI_DATA_W          8   \
        -parameter  MST_NB              4   \
        -parameter  NUM_PRIORITY_LVL    4   \
        -parameter  TIMEOUT_ENABLE      0   \
        -parameter  PRIORITY_W          2   \
        -parameter  AWCH_W              8   \
        -parameter  WCH_W               8   \
        -parameter  BCH_W               8   \
        -parameter  FIFO_OPEN           1
}


# ==============================================================================
# 4. CLOCK AND RESET
#    Single reset expression consistent with props "default disable iff (!aresetn)"
# ==============================================================================
clock aclk
reset -expression {!aresetn}


# ==============================================================================
# 5. FIFO BBOX CONSTRAINTS (Pass 1 only)
#    Constrain black-boxed FIFO outputs to legal idle state so the
#    arbiter can fire and AW handshakes are reachable.
#    NOTE: no force_reset_release — that conflicts with reset -expression.
#
#    With FIFO_OPEN=0, the GEN_COV_PASS2 generate block in props is never
#    elaborated, so there is nothing to disable here. The cover -disable
#    commands from the old TCL are intentionally removed.
# ==============================================================================
if { $BBOX_FIFO == 1 } {
    # wch_full=0  : FIFO not full, allows AW handshakes to proceed
    # wch_empty=1 : FIFO empty, consistent with post-reset idle state
    # wch_grant=0 : no W channel ownership when FIFO is empty
    assume -name bbox_wch_full_zero  {!u_dut.wch_full}
    assume -name bbox_wch_empty_one  {u_dut.wch_empty}
    assume -name bbox_wch_grant_zero {u_dut.wch_grant == 4'b0}
    puts "INFO: PASS 1 - FIFO bbox constraints applied"
}

# Approve all assumptions (SV-defined and TCL-added).
# Must come AFTER all assume commands above.
assume -set_type -regexp .* approved


# ==============================================================================
# 6. PROVE
# ==============================================================================
if { $BBOX_FIFO == 1 } {
    set pass_label "pass1_bbox"
} else {
    set pass_label "pass2_full"
}

set_prove_target_bound 80

prove -all


# ==============================================================================
# 7. COVERAGE
# ==============================================================================
check_cov -measure


# ==============================================================================
# 8. REPORTING
# ==============================================================================
file mkdir ../../results

report -summary

report \
    -results \
    -file "../../results/mst_switch_wr_results_${pass_label}.txt" \
    -force

report \
    -file "../../results/mst_switch_wr_waivers_${pass_label}.txt" \
    -force

check_cov -report \
    -model branch \
    -report_file "../../results/mst_switch_wr_coverage_branch_${pass_label}.txt" \
    -force

check_cov -report \
    -model statement \
    -report_file "../../results/mst_switch_wr_coverage_statement_${pass_label}.txt" \
    -force
