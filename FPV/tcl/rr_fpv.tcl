clear -all

analyze -sv \
    ../../rtl/axicb_round_robin_core.sv \
    ../../rtl/axicb_round_robin.sv \
    ../props/rr_props.sv \
    ../bind1/rr_bind.sv \
    ../tb/rr_fpv_top.sv

check_cov -init -model branch
check_cov -init -model statement

elaborate \
    -top        rr_fpv_top \
    -parameter  REQ_NB              4   \
    -parameter  PRIORITY_W          2   \
    -parameter  NUM_PRIORITY_LVL    4

clock aclk
reset -expression {!aresetn}

sanity_check

set pass_label "rr_fpv"
set_prove_target_bound 80

assume -set_type -regexp .* approved

prove -all

check_cov -measure

report -summary

file mkdir ../../results

report \
    -results \
    -file "../../results/rr_fpv_results_${pass_label}.txt" \
    -force

report \
    -file "../../results/rr_fpv_waivers_${pass_label}.txt" \
    -force

check_cov -report \
    -model branch \
    -report_file "../../results/rr_fpv_coverage_branch_${pass_label}.txt" \
    -force

check_cov -report \
    -model statement \
    -report_file "../../results/rr_fpv_coverage_statement_${pass_label}.txt" \
    -force