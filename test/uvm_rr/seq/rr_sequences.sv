// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

class rr_base_seq extends uvm_sequence #(rr_seq_item);

    `uvm_object_utils(rr_base_seq)

    function new(string name = "rr_base_seq");
        super.new(name);
    endfunction

endclass

// idle traffic, exercises reset behavior at the start of the run
class rr_reset_seq extends rr_base_seq;

    `uvm_object_utils(rr_reset_seq)

    function new(string name = "rr_reset_seq");
        super.new(name);
    endfunction

    task body();
        rr_seq_item tr;
        repeat (5) begin
            tr = rr_seq_item::type_id::create("tr");
            start_item(tr);
            tr.req  = '0;
            tr.en   = 1'b1;
            tr.srst = 1'b0;
            finish_item(tr);
        end
    endtask

endclass

// one requester active at a time, sweeping across all REQ_NB positions
class rr_walking_one_seq extends rr_base_seq;

    `uvm_object_utils(rr_walking_one_seq)

    function new(string name = "rr_walking_one_seq");
        super.new(name);
    endfunction

    task body();
        rr_seq_item tr;
        for (int i = 0; i < RR_REQ_NB; i++) begin
            repeat (3) begin
                tr = rr_seq_item::type_id::create("tr");
                start_item(tr);
                assert(tr.randomize() with { req == (1 << i); en == 1'b1; srst == 1'b0; });
                finish_item(tr);
            end
        end
    endtask

endclass

// all requesters active back-to-back, exercises the full rotation + wraparound
class rr_all_active_seq extends rr_base_seq;

    `uvm_object_utils(rr_all_active_seq)

    function new(string name = "rr_all_active_seq");
        super.new(name);
    endfunction

    task body();
        rr_seq_item tr;
        repeat (4 * RR_REQ_NB) begin
            tr = rr_seq_item::type_id::create("tr");
            start_item(tr);
            tr.req  = '1;
            tr.en   = 1'b1;
            tr.srst = 1'b0;
            finish_item(tr);
        end
    endtask

endclass

// exercises the synchronous reset (srst) path, which no other sequence
// drives non-zero: builds up non-trivial mask/grant_r state via a walking
// one, asserts srst for 2 cycles (including one cycle where en and req are
// still active, to hit the srst-overrides-en case), then releases it and
// confirms the arbiter resumes cleanly from a freshly-cleared mask
class rr_srst_seq extends rr_base_seq;

    `uvm_object_utils(rr_srst_seq)

    function new(string name = "rr_srst_seq");
        super.new(name);
    endfunction

    task body();
        rr_seq_item tr;

        // rotate the mask forward through every requester
        for (int i = 0; i < RR_REQ_NB; i++) begin
            tr = rr_seq_item::type_id::create("tr");
            start_item(tr);
            tr.req  = 1 << i;
            tr.en   = 1'b1;
            tr.srst = 1'b0;
            finish_item(tr);
        end

        // srst asserted while en=1 and req is still all active (overlap case)
        repeat (2) begin
            tr = rr_seq_item::type_id::create("tr");
            start_item(tr);
            tr.req  = '1;
            tr.en   = 1'b1;
            tr.srst = 1'b1;
            finish_item(tr);
        end

        // srst released - confirm a clean restart from a cleared mask
        for (int i = 0; i < RR_REQ_NB; i++) begin
            tr = rr_seq_item::type_id::create("tr");
            start_item(tr);
            tr.req  = 1 << i;
            tr.en   = 1'b1;
            tr.srst = 1'b0;
            finish_item(tr);
        end
    endtask

endclass

// constrained-random req/en traffic
class rr_random_seq extends rr_base_seq;

    `uvm_object_utils(rr_random_seq)

    int unsigned num_items = 200;

    function new(string name = "rr_random_seq");
        super.new(name);
    endfunction

    task body();
        rr_seq_item tr;
        repeat (num_items) begin
            tr = rr_seq_item::type_id::create("tr");
            start_item(tr);
            assert(tr.randomize());
            finish_item(tr);
        end
    endtask

endclass
