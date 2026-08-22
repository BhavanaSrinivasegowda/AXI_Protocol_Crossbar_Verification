// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

class rr_monitor extends uvm_monitor;

    `uvm_component_utils(rr_monitor)

    virtual rr_if#(RR_REQ_NB) vif;
    uvm_analysis_port #(rr_seq_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual rr_if#(RR_REQ_NB))::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "virtual interface not set for rr_monitor")
    endfunction

    task run_phase(uvm_phase phase);

        rr_seq_item tr;

        @(posedge vif.aresetn);

        forever begin
            @(vif.mon_cb);
            tr       = rr_seq_item::type_id::create("tr");
            tr.req   = vif.mon_cb.req;
            tr.en    = vif.mon_cb.en;
            tr.srst  = vif.mon_cb.srst;
            tr.grant = vif.mon_cb.grant;
            ap.write(tr);
        end

    endtask

endclass
