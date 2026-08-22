// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

class rr_coverage extends uvm_subscriber #(rr_seq_item);

    `uvm_component_utils(rr_coverage)

    rr_seq_item tr;

    covergroup cg;
        option.per_instance = 1;
        cp_req      : coverpoint tr.req;
        cp_grant    : coverpoint tr.grant;
        cp_en       : coverpoint tr.en;
        cp_srst     : coverpoint tr.srst;
        cx_req_grant: cross cp_req, cp_grant;
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg = new();
    endfunction

    function void write(rr_seq_item t);
        tr = t;
        cg.sample();
    endfunction

endclass
