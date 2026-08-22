clear -all

# Lean variant of rr_fpv.tcl for mutation-testing sweeps: same analyze/
# elaborate/prove setup, but skips coverage measurement and file reports
# (not needed to answer "did any property fire") and ends by printing one
# greppable line with the list of assertions that went to CEX.
#
# MUTATION_TAG env var is set by test/uvm_rr/mutation/run_mutation.sh so
# each sweep iteration gets its own -label/-proj and doesn't clobber the
# baseline FPV/tcl/jgproject session.

analyze -sv \
    ../../rtl/axicb_round_robin_core.sv \
    ../../rtl/axicb_round_robin.sv \
    ../props/rr_props.sv \
    ../bind1/rr_bind.sv \
    ../tb/rr_fpv_top.sv

elaborate \
    -top        rr_fpv_top \
    -parameter  REQ_NB              4   \
    -parameter  PRIORITY_W          2   \
    -parameter  NUM_PRIORITY_LVL    4

clock aclk
reset -expression {!aresetn}

sanity_check

set_prove_target_bound 80

assume -set_type -regexp .* approved

prove -all

set cex_list [get_property_list -include {assert} -status {cex}]
puts "MUTATION_RESULT: [llength $cex_list] failing assertions: $cex_list"

exit
