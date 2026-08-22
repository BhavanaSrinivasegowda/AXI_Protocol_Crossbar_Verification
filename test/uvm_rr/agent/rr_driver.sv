// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

class rr_driver extends uvm_driver #(rr_seq_item);

    `uvm_component_utils(rr_driver)

    virtual rr_if#(RR_REQ_NB) vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual rr_if#(RR_REQ_NB))::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "virtual interface not set for rr_driver")
    endfunction

    task run_phase(uvm_phase phase);

        rr_seq_item tr;

        vif.drv_cb.req  <= '0;
        vif.drv_cb.en   <= 1'b1;
        vif.drv_cb.srst <= 1'b0;

        @(posedge vif.aresetn);

        forever begin
            seq_item_port.get_next_item(tr);
            vif.drv_cb.req  <= tr.req;
            vif.drv_cb.en   <= tr.en;
            vif.drv_cb.srst <= tr.srst;
            @(vif.drv_cb);
            seq_item_port.item_done();
        end

    endtask

endclass
