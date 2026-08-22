// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

// Reference model reimplements axicb_round_robin_core's mask/rotate algorithm
// generically for any REQ_NB, mirroring the per-width unrolled RTL (see the
// header comment block of rtl/axicb_round_robin_core.sv for the worked
// req/mask/grant tables this model is transcribed from).
class rr_scoreboard extends uvm_component;

    `uvm_component_utils(rr_scoreboard)

    uvm_analysis_imp #(rr_seq_item, rr_scoreboard) ap_imp;

    bit [RR_REQ_NB-1:0] exp_mask;
    bit [RR_REQ_NB-1:0] exp_grant_r;

    int unsigned match_cnt;
    int unsigned mismatch_cnt;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap_imp = new("ap_imp", this);
    endfunction

    // first set bit from the LSB, one-hot encoded ('0 if v=='0)
    function bit [RR_REQ_NB-1:0] onehot_lsb(bit [RR_REQ_NB-1:0] v);
        onehot_lsb = '0;
        for (int i = 0; i < RR_REQ_NB; i++) begin
            if (v[i]) begin
                onehot_lsb[i] = 1'b1;
                return onehot_lsb;
            end
        end
    endfunction

    // mask presented to the next arbitration once index idx has been granted
    function bit [RR_REQ_NB-1:0] next_mask(int unsigned idx);
        next_mask = '0;
        if (idx == RR_REQ_NB-1) begin
            next_mask = '1;
        end else begin
            for (int i = idx+1; i < RR_REQ_NB; i++)
                next_mask[i] = 1'b1;
        end
    endfunction

    function void write(rr_seq_item tr);

        bit [RR_REQ_NB-1:0] masked;
        bit [RR_REQ_NB-1:0] grant_c;
        bit [RR_REQ_NB-1:0] exp_grant;
        int unsigned        idx;

        masked  = exp_mask & tr.req;
        grant_c = (|masked) ? onehot_lsb(masked) : onehot_lsb(tr.req);

        exp_grant = tr.en ? grant_c : exp_grant_r;

        if (exp_grant !== tr.grant) begin
            mismatch_cnt++;
            `uvm_error("RR_SB", $sformatf(
                "grant mismatch: %s exp_mask=%0b => expected=%0b actual=%0b",
                tr.convert2string(), exp_mask, exp_grant, tr.grant))
        end else begin
            match_cnt++;
        end

        if (tr.srst) begin
            exp_mask    = '0;
            exp_grant_r = '0;
        end else begin
            if (tr.en && |grant_c) begin
                idx = 0;
                for (int i = 0; i < RR_REQ_NB; i++) begin
                    if (grant_c[i]) begin
                        idx = i;
                        break;
                    end
                end
                exp_mask = next_mask(idx);
            end
            if (tr.en)
                exp_grant_r = grant_c;
        end

    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("RR_SB", $sformatf(
            "matches=%0d mismatches=%0d", match_cnt, mismatch_cnt), UVM_LOW)
        if (mismatch_cnt > 0)
            `uvm_error("RR_SB", "scoreboard recorded mismatches - see log above")
    endfunction

endclass
