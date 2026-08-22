// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

class rr_env extends uvm_env;

    `uvm_component_utils(rr_env)

    rr_agent      agt;
    rr_scoreboard sb;
    rr_coverage   cov;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agt = rr_agent::type_id::create("agt", this);
        sb  = rr_scoreboard::type_id::create("sb", this);
        cov = rr_coverage::type_id::create("cov", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agt.mon.ap.connect(sb.ap_imp);
        agt.mon.ap.connect(cov.analysis_export);
    endfunction

endclass
