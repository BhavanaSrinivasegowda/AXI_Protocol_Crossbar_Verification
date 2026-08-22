clear -all


# ==============================================================================
# 0. LOGGING
#    All FPV scripts in this directory share one jgproject/ (and therefore
#    one jg_console.log), so re-running any component overwrites/mixes the
#    transcript of every other one. Give slv_ooo its own console log,
#    truncated at the start of every run so it always reflects the latest
#    pass only. Wrapped in catch: if this Jasper version's set_log_file
#    signature differs, the run still proceeds using the default shared log.
# ==============================================================================
file mkdir ../../results
set SLV_OOO_LOG "../../results/slv_ooo_fpv.log"
catch {file delete -force $SLV_OOO_LOG}

if {[catch {set_log_file -replace $SLV_OOO_LOG} log_err]} {
    puts "WARNING: set_log_file failed ($log_err) — continuing with default jgproject/jg_console.log"
} else {
    puts "INFO: slv_ooo console log -> $SLV_OOO_LOG"
}


# ==============================================================================
# 1. ANALYSIS
#    First pass scope: RD_PATH=0, MST_OSTDREQ_NUM=4 — the real per-ID FIFO +
#    round-robin arbitration path (not the OSTDREQ_NUM==1 pipeline bypass,
#    which never elaborates axicb_scfifo/axicb_round_robin_core below and is
#    left as future work — see slv_ooo_props.sv header). Single full-state-
#    space run, no black-boxing: unlike mst_switch_wr's wch_gnt_fifo, the
#    per-ID FIFOs here ARE the arbitration state, not overhead sitting
#    downstream of it — freezing them the way Pass 1 does for mst_switch_wr
#    would leave nothing of substance left to prove.
# ==============================================================================
analyze -sv12 \
    ../../rtl/axicb_round_robin_core.sv \
    ../../rtl/axicb_round_robin.sv \
    ../../rtl/axicb_scfifo_ram.sv \
    ../../rtl/axicb_scfifo_regfile.sv \
    ../../rtl/axicb_scfifo.sv \
    ../../rtl/axicb_pipeline.sv \
    ../../rtl/axicb_slv_ooo.sv \
    ../props/slv_ooo_props.sv \
    ../bind1/slv_ooo_bind.sv \
    ../tb/slv_ooo_fpv_top.sv


# ==============================================================================
# 2. COVERAGE INIT (must be before elaborate)
# ==============================================================================
check_cov -init -model branch
check_cov -init -model statement


# ==============================================================================
# 3. ELABORATE
# ==============================================================================
elaborate \
    -top        slv_ooo_fpv_top \
    -parameter  RD_PATH             0   \
    -parameter  AXI_ID_W            8   \
    -parameter  SLV_NB              4   \
    -parameter  MST_OSTDREQ_NUM     4   \
    -parameter  CCH_W               10


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
    -file "../../results/slv_ooo_results.txt" \
    -force

report \
    -file "../../results/slv_ooo_waivers.txt" \
    -force

check_cov -report \
    -model branch \
    -report_file "../../results/slv_ooo_coverage_branch.txt" \
    -force

check_cov -report \
    -model statement \
    -report_file "../../results/slv_ooo_coverage_statement.txt" \
    -force
