clear -all


# ==============================================================================
# 0. LOGGING
#    All FPV scripts in this directory share one jgproject/ (and therefore
#    one jg_console.log), so re-running any component overwrites/mixes the
#    transcript of every other one. Give mst_switch_rd its own console log,
#    truncated at the start of every run so it always reflects the latest
#    pass only. Wrapped in catch: if this Jasper version's set_log_file
#    signature differs, the run still proceeds using the default shared log.
# ==============================================================================
file mkdir ../../results
set MST_SWITCH_RD_LOG "../../results/mst_switch_rd_fpv.log"
catch {file delete -force $MST_SWITCH_RD_LOG}

if {[catch {set_log_file -replace $MST_SWITCH_RD_LOG} log_err]} {
    puts "WARNING: set_log_file failed ($log_err) — continuing with default jgproject/jg_console.log"
} else {
    puts "INFO: mst_switch_rd console log -> $MST_SWITCH_RD_LOG"
}


# ==============================================================================
# 1. ANALYSIS
#    axicb_mst_switch_rd depends only on axicb_round_robin(_core) — there is
#    no grant-memory FIFO on the read-data path (R carries the ID itself),
#    so unlike mst_switch_wr this needs no black-box pass and no FIFO_OPEN
#    parameter. Single full-state-space run.
# ==============================================================================
analyze -sv12 \
    ../../rtl/axicb_round_robin_core.sv \
    ../../rtl/axicb_round_robin.sv \
    ../../rtl/axicb_mst_switch_rd.sv \
    ../props/mst_switch_rd_props.sv \
    ../bind1/mst_switch_rd_bind.sv \
    ../tb/mst_switch_rd_fpv_top.sv


# ==============================================================================
# 2. COVERAGE INIT (must be before elaborate)
# ==============================================================================
check_cov -init -model branch
check_cov -init -model statement


# ==============================================================================
# 3. ELABORATE
# ==============================================================================
elaborate \
    -top        mst_switch_rd_fpv_top \
    -parameter  AXI_ID_W            8   \
    -parameter  AXI_DATA_W          8   \
    -parameter  MST_NB              4   \
    -parameter  NUM_PRIORITY_LVL    4   \
    -parameter  TIMEOUT_ENABLE      0   \
    -parameter  PRIORITY_W          2   \
    -parameter  ARCH_W              8   \
    -parameter  RCH_W               8


# ==============================================================================
# 4. CLOCK AND RESET
#    Single reset expression consistent with props "default disable iff (!aresetn)"
# ==============================================================================
clock aclk
reset -expression {!aresetn}


# ==============================================================================
# 5. ASSUMPTIONS
#    Approve all assumptions (SV-defined). No TCL-added bbox constraints
#    needed since there is no black-boxed submodule in this proof.
# ==============================================================================
assume -set_type -regexp .* approved


# ==============================================================================
# 6. PROVE
# ==============================================================================
set_prove_target_bound 80

prove -all


# ==============================================================================
# 7. COVERAGE
# ==============================================================================
check_cov -measure


# ==============================================================================
# 8. REPORTING
#    (results dir already created in section 0 alongside the log file)
# ==============================================================================
report -summary

report \
    -results \
    -file "../../results/mst_switch_rd_results.txt" \
    -force

report \
    -file "../../results/mst_switch_rd_waivers.txt" \
    -force

check_cov -report \
    -model branch \
    -report_file "../../results/mst_switch_rd_coverage_branch.txt" \
    -force

check_cov -report \
    -model statement \
    -report_file "../../results/mst_switch_rd_coverage_statement.txt" \
    -force
