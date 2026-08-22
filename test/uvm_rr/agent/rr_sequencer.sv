// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

class rr_sequencer extends uvm_sequencer #(rr_seq_item);

    `uvm_component_utils(rr_sequencer)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

endclass
