// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

class rr_base_test extends uvm_test;

    `uvm_component_utils(rr_base_test)

    rr_env env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = rr_env::type_id::create("env", this);
    endfunction

    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        uvm_top.print_topology();
    endfunction

endclass
