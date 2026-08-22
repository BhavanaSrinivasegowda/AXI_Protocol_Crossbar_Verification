// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

class rr_seq_item extends uvm_sequence_item;

    rand bit [RR_REQ_NB-1:0] req;
    rand bit                 en;
    rand bit                 srst;
         bit [RR_REQ_NB-1:0] grant;

    constraint c_en_mostly_on { en   dist { 1'b1 := 9, 1'b0 := 1 }; }
    constraint c_srst_off     { srst == 1'b0; }

    `uvm_object_utils(rr_seq_item)

    function new(string name = "rr_seq_item");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf("req=%0b en=%0b srst=%0b grant=%0b", req, en, srst, grant);
    endfunction

endclass
