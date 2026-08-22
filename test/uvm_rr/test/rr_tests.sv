// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

class rr_reset_test extends rr_base_test;

    `uvm_component_utils(rr_reset_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        rr_reset_seq seq;
        phase.raise_objection(this);
        seq = rr_reset_seq::type_id::create("seq");
        seq.start(env.agt.sqr);
        phase.drop_objection(this);
    endtask

endclass

class rr_walking_one_test extends rr_base_test;

    `uvm_component_utils(rr_walking_one_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        rr_walking_one_seq seq;
        phase.raise_objection(this);
        seq = rr_walking_one_seq::type_id::create("seq");
        seq.start(env.agt.sqr);
        phase.drop_objection(this);
    endtask

endclass

class rr_all_active_test extends rr_base_test;

    `uvm_component_utils(rr_all_active_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        rr_all_active_seq seq;
        phase.raise_objection(this);
        seq = rr_all_active_seq::type_id::create("seq");
        seq.start(env.agt.sqr);
        phase.drop_objection(this);
    endtask

endclass

class rr_srst_test extends rr_base_test;

    `uvm_component_utils(rr_srst_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        rr_srst_seq seq;
        phase.raise_objection(this);
        seq = rr_srst_seq::type_id::create("seq");
        seq.start(env.agt.sqr);
        phase.drop_objection(this);
    endtask

endclass

class rr_random_test extends rr_base_test;

    `uvm_component_utils(rr_random_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        rr_random_seq seq;
        phase.raise_objection(this);
        seq = rr_random_seq::type_id::create("seq");
        seq.num_items = 500;
        seq.start(env.agt.sqr);
        phase.drop_objection(this);
    endtask

endclass
