clear -all

analyze -sv \
    ../../rtl/axicb_scfifo_ram.sv \
    ../../rtl/axicb_scfifo_regfile.sv \
    ../../rtl/axicb_scfifo.sv \
    ../props/scfifo_props.sv \
    ../bind1/scfifo_bind.sv \
    ../tb/scfifo_fpv_top.sv

check_cov -init -model branch
check_cov -init -model statement

elaborate \
    -top        scfifo_fpv_top \
    -parameter  ADDR_WIDTH  2   \
    -parameter  DATA_WIDTH  8

clock aclk
reset -expression {!aresetn}

sanity_check

set pass_label "scfifo_fpv"
set_prove_target_bound 80

assume -set_type -regexp .* approved

prove -all

check_cov -measure

report -summary

file mkdir ../../results

report \
    -results \
    -file "../../results/scfifo_fpv_results_${pass_label}.txt" \
    -force

report \
    -file "../../results/scfifo_fpv_waivers_${pass_label}.txt" \
    -force

check_cov -report \
    -model branch \
    -report_file "../../results/scfifo_fpv_coverage_branch_${pass_label}.txt" \
    -force

check_cov -report \
    -model statement \
    -report_file "../../results/scfifo_fpv_coverage_statement_${pass_label}.txt" \
    -force
