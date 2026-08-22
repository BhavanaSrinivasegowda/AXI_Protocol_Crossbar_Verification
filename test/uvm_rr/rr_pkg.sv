// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

package rr_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    parameter int RR_REQ_NB = 4;

    `include "seq_item/rr_seq_item.sv"
    `include "agent/rr_sequencer.sv"
    `include "agent/rr_driver.sv"
    `include "agent/rr_monitor.sv"
    `include "agent/rr_agent.sv"
    `include "env/rr_scoreboard.sv"
    `include "env/rr_coverage.sv"
    `include "env/rr_env.sv"
    `include "seq/rr_sequences.sv"
    `include "test/rr_base_test.sv"
    `include "test/rr_tests.sv"

endpackage
