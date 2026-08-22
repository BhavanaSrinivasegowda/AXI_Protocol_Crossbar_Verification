// =============================================================================
// FILE         : slv_ooo_props.sv
// PROJECT      : AXI Crossbar FPV
// MODULE       : slv_ooo_props (bound to axicb_slv_ooo via slv_ooo_bind.sv)
// DESCRIPTION  : Standalone formal property suite for axicb_slv_ooo, the
//                block that tracks outstanding requests per ID and arbitrates
//                which slave's completion (B or R) gets routed back to the
//                master next. Instantiated twice by both axicb_slv_switch_wr
//                (RD_PATH=0, write/B completions) and axicb_slv_switch_rd
//                (RD_PATH=1, read/R completions) — it's the slave-side
//                counterpart to the wch_gnt_fifo used in axicb_mst_switch_wr,
//                but arbitrating per-ID instead of remembering a single
//                AW winner.
//
//                DUT is verified as a standalone unit: a_valid/a_ready,
//                c_en/c_end, c_valid/c_ch and all address-channel fields are
//                left free (subject only to the legality assumptions in
//                SECTION A below) — no assumption is made about *which*
//                crossbar drives it, so a real routing bug can't hide behind
//                a convenient constraint.
//
//                FIRST PASS SCOPE (see slv_ooo_fpv_top.sv):
//                  RD_PATH = 0            (write/B completion path — no ALEN
//                                           accounting, the simpler of the
//                                           two completion shapes).
//                  MST_OSTDREQ_NUM = 4    (> 1, so the real per-ID FIFO +
//                                           round-robin arbitration path is
//                                           elaborated — this is the
//                                           interesting/default case, not
//                                           the single-outstanding bypass).
//                  RD_PATH = 1 (adds c_len/ALEN plumbing to the granted
//                  completion) and MST_OSTDREQ_NUM = 1 (an entirely
//                  different code path: no ID FIFOs at all, a single
//                  axicb_pipeline stage instead) are left as future work —
//                  properties below are commented where they are specific
//                  to this pass's scope, same idiom as scfifo_props.sv's
//                  B6/B7 PASS_THRU=0 notes.
//
//                The bind in slv_ooo_bind.sv attaches this module to
//                axicb_slv_ooo, giving white-box access to:
//                  - push/pull, id_full/id_empty  : per-ID FIFO control
//                  - fifo_out                      : per-ID FIFO payload
//                  - c_reqs/id_grant/mr_reqs        : completion arbitration
//                  - c_select/c_empty               : output staging mux
//                  - a_id_m                         : unmasked address ID
//
// PROPERTY MAP:
// =============================================================================
//  SECTION A — ASSUMPTIONS (environment legality only)
//    A1. asm_ctrl_not_x        : a_valid/a_ready/c_en/c_end never X/Z
//    A2. asm_avalid_fields_known : a_id/a_ix/a_mr known whenever a_valid
//    A3. asm_avalid_stable      : a_valid doesn't retract before a_ready
//    A4. asm_afields_stable     : address fields held stable while pending
//    A5. asm_aix_legal_routing  : a_ix is one-hot iff not misrouted, zero
//                                  iff misrouted (contract with the address
//                                  decoder that feeds this block)
//    A6. asm_aid_in_range       : unmasked a_id stays within the
//                                  MST_OSTDREQ_NUM budget this block was
//                                  built to track (IDs outside the budget
//                                  have no FIFO slot — out of scope for
//                                  this DUT, whose job starts once IDs are
//                                  already budget-legal)
//    A7. asm_cvalid_not_x       : c_valid never X/Z
//    A8. asm_cvalid_id_known    : completion ID field known whenever that
//                                  slave's c_valid is asserted
//
//  SECTION B — ASSERTIONS
//    GROUP 1 — Reset / Idle Behavior
//    B1.  ast_afull_zero_after_areset      : a_full clears after async reset
//    B2.  ast_completion_zero_after_areset : granted completion fields clear
//                                             after async reset
//    B3.  ast_idgrant_zero_when_no_creqs   : while c_en, no completion
//                                             request in -> no ID grant out
//                                             (wiring check against
//                                             round_robin_core's own
//                                             already-proven "no req, no
//                                             grant" guarantee — qualified
//                                             by c_en because grant holds
//                                             grant_r, decoupled from req,
//                                             whenever en=0; see the CEX
//                                             note at the property itself
//                                             and verification_notes.txt
//                                             section 7)
//
//    GROUP 2 — Address Intake / Per-ID Routing
//    B4.  ast_aidm_definition        : a_id_m == a_id ^ MST_ID_MASK
//    B5.  ast_afull_matches_idfull   : a_full == |id_full
//    B6.  ast_push_targets_correct_id : push[i] fires iff a handshake landed
//                                        on ID slot i, one push line per
//                                        handshake, never the wrong slot
//    B7.  ast_no_push_without_ahandshake : no address-channel handshake ->
//                                           no ID FIFO push at all
//
//    GROUP 3 — Misrouted-First Arbitration Priority
//    B8.  ast_misrouted_priority : whenever any ID slot's head-of-line entry
//                                   is misrouted, completion requests come
//                                   only from misrouted slots that cycle —
//                                   a genuinely valid slave completion never
//                                   sneaks in ahead of a misrouted one
//    B9.  ast_creqs_zero_when_all_empty : nothing outstanding -> no
//                                          completion request at all
//
//    GROUP 4 — Completion Routing / ID Matching
//    B10. ast_creqs_requires_real_match : a completion request for ID slot i
//                                          never fires unless some slave j
//                                          is actually valid, actually
//                                          targeted by slot i, and actually
//                                          carries slot i's (unmasked) ID —
//                                          the core anti-crosstalk property
//    B11. ast_id_grant_onehot_or_zero    : never two ID slots granted the
//                                           completion channel at once
//    B12. ast_pull_matches_grant_on_cend : the ID FIFO is only ever popped
//                                           for the slot actually granted,
//                                           and only once the transaction
//                                           genuinely ends (c_end) — not on
//                                           every grant cycle of a burst
//    B13. ast_no_pull_without_grant       : pull is never asserted for an ID
//                                            slot that wasn't granted
//
//    GROUP 5 — Output Staging (c_select/c_empty mux -> c_grant/c_mr/c_id/c_len)
//    B14. ast_cselect_matches_granted_id : c_select/c_empty mux picks
//                                           exactly the granted ID slot's
//                                           stored payload, nothing else
//    B15. ast_completion_zero_when_empty : granted output fields are all
//                                           zero, never stale/garbage, when
//                                           nothing is actually selected
//    B16. ast_completion_len_zero_write_path : c_len stays 0 (RD_PATH=0
//                                               scope only — write/B
//                                               completions carry no ALEN)
//    B17. ast_completion_passthrough_when_valid : c_select isn't mangled on
//                                                  the way to
//                                                  c_grant/c_mr/c_id
//
//  SECTION C — COVER PROPERTIES (reachability / sanity)
//    C1. cov_afull_reached                  : backpressure can actually fire
//    C2. cov_all_id_slots_full              : every ID slot fills at once
//    C3. cov_misrouted_completion_granted   : a misrouted slot's synthetic
//                                              completion actually gets
//                                              granted end to end
//    C4. cov_two_ids_outstanding            : two different IDs genuinely
//                                              outstanding at once (real
//                                              arbitration contention)
//    C5. cov_back_to_back_ahandshakes       : back-to-back address accepts
//    C6. cov_grant_rotates_between_ids      : the completion grant actually
//                                              moves from one ID to another
//    C7. cov_completion_routed_per_slave    : each slave's completion
//                                              reaches the master at least
//                                              once
// =============================================================================

`timescale 1 ns / 1 ps
`default_nettype wire

module slv_ooo_props #(
    parameter int unsigned RD_PATH         = 0,
    parameter int unsigned AXI_ID_W        = 8,
    parameter int unsigned SLV_NB          = 4,
    parameter int unsigned MST_OSTDREQ_NUM = 4,
    parameter [AXI_ID_W-1:0] MST_ID_MASK   = 'h00,
    parameter int unsigned CCH_W           = 10
)(
    input logic                     aclk,
    input logic                     aresetn,
    input logic                     srst,

    input logic                     a_valid,
    input logic                     a_ready,
    input logic                     a_full,
    input logic [8            -1:0] a_len,
    input logic [AXI_ID_W     -1:0] a_id,
    input logic [SLV_NB       -1:0] a_ix,
    input logic                     a_mr,

    input logic                     c_en,
    input logic [SLV_NB       -1:0] c_grant,
    input logic                     c_mr,
    input logic [8            -1:0] c_len,
    input logic [AXI_ID_W     -1:0] c_id,

    input logic [SLV_NB       -1:0] c_valid,
    input logic                     c_ready,
    input logic [CCH_W*SLV_NB -1:0] c_ch,
    input logic                     c_end,

    // -------------------------------------------------------------------------
    // Internal signals from axicb_slv_ooo (via bind)
    // fifo_out/c_select are sized off RD_PATH the same way axicb_slv_ooo
    // sizes its own FIFO_WIDTH localparam — RD_PATH=1 (future work, see
    // header) adds 8 bits (ALEN) to both and must track the DUT exactly or
    // the bind will mismatch port widths.
    // -------------------------------------------------------------------------
    input logic [MST_OSTDREQ_NUM-1:0]                                     push,
    input logic [MST_OSTDREQ_NUM-1:0]                                     pull,
    input logic [MST_OSTDREQ_NUM-1:0]                                     id_full,
    input logic [MST_OSTDREQ_NUM-1:0]                                     id_empty,
    input logic [((RD_PATH?8:0)+SLV_NB+1+AXI_ID_W)*MST_OSTDREQ_NUM-1:0]   fifo_out,
    input logic [(RD_PATH?8:0)+SLV_NB+1+AXI_ID_W-1:0]                     c_select,
    input logic [MST_OSTDREQ_NUM-1:0]                                     c_reqs,
    input logic [MST_OSTDREQ_NUM-1:0]                                     id_grant,
    input logic [MST_OSTDREQ_NUM-1:0]                                     mr_reqs,
    input logic [AXI_ID_W-1:0]                                            a_id_m,
    input logic                                               c_empty
);

    // =========================================================================
    // Local re-derivation of the DUT's own localparams — needed to slice
    // fifo_out/c_select the same way axicb_slv_ooo does internally. These are
    // localparams in the RTL (not ports), so they can't be forwarded through
    // the bind and must be recomputed here from the same parameters.
    // =========================================================================
    localparam int unsigned OSTDREQ_NUM = (MST_OSTDREQ_NUM < 2) ? 1 : MST_OSTDREQ_NUM;
    localparam int unsigned NB_ID       = OSTDREQ_NUM;
    localparam int unsigned FIFO_WIDTH  = (RD_PATH) ? 8 + SLV_NB + 1 + AXI_ID_W
                                                      : SLV_NB + 1 + AXI_ID_W;

    // =========================================================================
    // Local helpers
    // =========================================================================

    // For each ID slot i, whether some slave j is a legitimate source for
    // that slot's completion request this cycle: valid, actually targeted by
    // slot i (the stored a_ix bit), and its (unmasked) completion ID actually
    // equals i. Independently re-derived from the same fields the RTL reads
    // (fifo_out/c_valid/c_ch), used to check B10 without just restating the
    // RTL's own c_reqs computation verbatim.
    logic [SLV_NB-1:0] id_match [NB_ID];
    generate
        for (genvar i = 0; i < NB_ID; i++) begin : GEN_ID_MATCH_I
            for (genvar j = 0; j < SLV_NB; j++) begin : GEN_ID_MATCH_J
                assign id_match[i][j] = c_valid[j] && !id_empty[i] &&
                    fifo_out[i*FIFO_WIDTH + AXI_ID_W + 1 + j] &&
                    ((c_ch[j*CCH_W +: AXI_ID_W] ^ MST_ID_MASK) == i[0+:AXI_ID_W]);
            end
        end
    endgenerate

    // =========================================================================
    // Default clocking and disable
    // =========================================================================

    default clocking cb @(posedge aclk);
    endclocking

    default disable iff (!aresetn);

    // =========================================================================
    // SECTION A — ASSUMPTIONS
    // =========================================================================

    // A1. Handshake/enable controls are never X/Z.
    asm_ctrl_not_x: assume property (
        !$isunknown({a_valid, a_ready, c_en, c_end})
    );

    // A2. Address-channel fields only need to be known while a_valid is
    //     actually asserted.
    asm_avalid_fields_known: assume property (
        a_valid |-> !$isunknown({a_id, a_ix, a_mr})
    );

    // A3. Standard valid/ready contract: a_valid doesn't retract before
    //     a_ready arrives.
    asm_avalid_stable: assume property (
        (a_valid && !a_ready) |=> a_valid
    );

    // A4. Address-channel fields held stable while the handshake is pending.
    asm_afields_stable: assume property (
        (a_valid && !a_ready) |=> ({a_id, a_ix, a_mr} == $past({a_id, a_ix, a_mr}))
    );

    // A5. Contract with the address decoder feeding this block: a legal
    //     transaction targets exactly one slave (a_ix one-hot) unless it's
    //     misrouted, in which case it targets none.
    asm_aix_legal_routing: assume property (
        a_valid |-> (a_mr ? (a_ix == '0) : $onehot(a_ix))
    );

    // A6. The master only uses IDs within the outstanding-request budget
    //     this block was sized for (MST_OSTDREQ_NUM). An ID outside that
    //     range has no FIFO slot to land in — enforcing that budget is the
    //     job of whatever tracks outstanding transaction counts upstream,
    //     not this DUT.
    asm_aid_in_range: assume property (
        a_valid |-> ((a_id ^ MST_ID_MASK) < NB_ID)
    );

    // A7. Per-slave completion valid is never X/Z.
    asm_cvalid_not_x: assume property (
        !$isunknown(c_valid)
    );

    // A8. A slave's completion ID field is only required to be known while
    //     that slave's c_valid is actually asserted.
    generate
        for (genvar j = 0; j < SLV_NB; j++) begin : GEN_ASM_CVALID_ID_KNOWN
            asm_cvalid_id_known_j: assume property (
                c_valid[j] |-> !$isunknown(c_ch[j*CCH_W +: AXI_ID_W])
            );
        end
    endgenerate


    // =========================================================================
    // SECTION B — ASSERTIONS
    // =========================================================================

    // -------------------------------------------------------------------------
    // GROUP 1 — Reset / Idle Behavior
    // -------------------------------------------------------------------------

    // B1. No backpressure survives an async reset.
    ast_afull_zero_after_areset: assert property (
        disable iff (1'b0)
        $rose(aresetn) |-> !a_full
    );

    // B2. No stale granted-completion fields survive an async reset.
    ast_completion_zero_after_areset: assert property (
        disable iff (1'b0)
        $rose(aresetn) |-> (c_grant == '0 && c_mr == 1'b0 && c_id == '0 && c_len == '0)
    );

    // B3. Wiring check against round_robin_core's own already-proven "no
    //     request, no grant" guarantee — confirms c_reqs/id_grant are
    //     actually connected to its req/grant ports, not just proven in
    //     isolation elsewhere. Must be qualified by c_en: round_robin_core's
    //     grant output is (en ? grant_c : grant_r) — with en=0 it holds
    //     whatever grant_r last latched while en was high, completely
    //     decoupled from the *current* req/c_reqs value, so id_grant can be
    //     nonzero on a cycle where c_reqs has since dropped to 0 as long as
    //     c_en is low that cycle. Same shape of mistake as the mst_switch_rd
    //     srst CEX documented in verification_notes.txt section 6 — an
    //     invariant that looks obvious from the combinational grant equation
    //     but breaks against the arbiter's hold/latch behavior. rr_props.sv
    //     never states a req/grant relationship without gating on en for
    //     exactly this reason (e.g. p_lonely_req_below_mask_gets_grant).
    //     CEX found on first run at bound 3 — fixed by adding the c_en
    //     qualifier below (see verification_notes.txt section 7).
    ast_idgrant_zero_when_no_creqs: assert property (
        (c_en && (c_reqs == '0)) |-> (id_grant == '0)
    );


    // -------------------------------------------------------------------------
    // GROUP 2 — Address Intake / Per-ID Routing
    // -------------------------------------------------------------------------

    // B4. Sanity check on the unmask XOR itself.
    ast_aidm_definition: assert property (
        a_id_m == (a_id ^ MST_ID_MASK)
    );

    // B5. Backpressure is exactly "some ID slot is full" — no other reason
    //     to block the address channel.
    ast_afull_matches_idfull: assert property (
        a_full == (|id_full)
    );

    // B6. A handshake landing on ID slot i pushes exactly that slot's FIFO
    //     — never zero, never more than one, never the wrong one.
    generate
        for (genvar i = 0; i < NB_ID; i++) begin : GEN_AST_PUSH_TARGET
            ast_push_targets_correct_id_i: assert property (
                push[i] == ((a_valid && a_ready) && (a_id_m == i[0+:AXI_ID_W]))
            );
        end
    endgenerate

    // B7. No address-channel handshake means no ID FIFO gets pushed at all.
    ast_no_push_without_ahandshake: assert property (
        !(a_valid && a_ready) |-> (push == '0)
    );


    // -------------------------------------------------------------------------
    // GROUP 3 — Misrouted-First Arbitration Priority
    // -------------------------------------------------------------------------

    // B8. Misrouted transactions are served with strict priority: whenever
    //     any ID slot's head-of-line entry is misrouted, the completion
    //     request vector is driven purely by mr_reqs that cycle — a
    //     genuinely-valid slave completion targeting a different, non-
    //     misrouted slot never sneaks in ahead of it.
    ast_misrouted_priority: assert property (
        (|mr_reqs) |-> (c_reqs == mr_reqs)
    );

    // B9. Nothing outstanding anywhere means no completion request at all.
    ast_creqs_zero_when_all_empty: assert property (
        (id_empty == '1) |-> (c_reqs == '0)
    );


    // -------------------------------------------------------------------------
    // GROUP 4 — Completion Routing / ID Matching
    // -------------------------------------------------------------------------

    // B10. The core anti-crosstalk property: ID slot i's completion request
    //      never fires unless some slave is actually valid, actually
    //      targeted by slot i, and actually carries slot i's own (unmasked)
    //      ID. Checked against id_match, an independently re-derived
    //      reference of "who could legitimately be driving this request" —
    //      not just a restatement of the RTL's own c_reqs equation.
    generate
        for (genvar i = 0; i < NB_ID; i++) begin : GEN_AST_CREQS_MATCH
            ast_creqs_requires_real_match_i: assert property (
                (c_reqs[i] && !(|mr_reqs)) |-> (|id_match[i])
            );
        end
    endgenerate

    // B11. Never two ID slots granted the completion channel simultaneously.
    ast_id_grant_onehot_or_zero: assert property (
        $onehot0(id_grant)
    );

    // B12. The ID FIFO is popped for exactly the granted slot, and only once
    //      the transaction genuinely ends (c_end) — a slot can be granted
    //      for multiple cycles mid-burst without being popped early.
    ast_pull_matches_grant_on_cend: assert property (
        pull == (c_end ? id_grant : '0)
    );

    // B13. No ID slot is ever popped unless it was actually granted.
    ast_no_pull_without_grant: assert property (
        (pull != '0) |-> (pull == id_grant)
    );


    // -------------------------------------------------------------------------
    // GROUP 5 — Output Staging (c_select/c_empty mux)
    // -------------------------------------------------------------------------

    // B14. The output mux picks exactly the granted ID slot's stored payload
    //      and empty flag — no cross-slot leakage.
    generate
        for (genvar i = 0; i < NB_ID; i++) begin : GEN_AST_CSELECT
            ast_cselect_matches_granted_id_i: assert property (
                id_grant[i] |-> (c_select == fifo_out[i*FIFO_WIDTH +: FIFO_WIDTH]) &&
                                 (c_empty == id_empty[i])
            );
        end
    endgenerate

    // B15. When nothing is actually selected (c_empty), the granted
    //      completion fields must be all-zero, never stale/garbage.
    ast_completion_zero_when_empty: assert property (
        c_empty |-> (c_grant == '0 && c_mr == 1'b0 && c_id == '0)
    );

    // B16. RD_PATH=0 scope only: write/B completions carry no ALEN, c_len
    //      stays 0 unconditionally. Revisit once RD_PATH=1 is brought into
    //      scope — c_len will then come from the FIFO's stored a_len field.
    ast_completion_len_zero_write_path: assert property (
        c_len == '0
    );

    // B17. c_select isn't mangled on its way out to c_grant/c_mr/c_id —
    //      straight passthrough whenever a real slot was selected.
    ast_completion_passthrough_when_valid: assert property (
        !c_empty |-> ({c_grant, c_mr, c_id} == c_select)
    );


    // =========================================================================
    // SECTION C — COVER PROPERTIES
    // =========================================================================

    // C1. Backpressure can actually fire.
    cov_afull_reached: cover property (a_full);

    // C2. Every ID slot fills up at the same time (stress case).
    cov_all_id_slots_full: cover property (&id_full);

    // C3. A misrouted slot's synthetic completion actually gets granted
    //     end to end, not just requested.
    cov_misrouted_completion_granted: cover property (
        (|mr_reqs) ##[0:8] (|(id_grant & mr_reqs))
    );

    // C4. Two different IDs genuinely outstanding at once — real
    //     arbitration contention, not just one ID cycling alone.
    cov_two_ids_outstanding: cover property (
        $countones(~id_empty) >= 2
    );

    // C5. Back-to-back address-channel handshakes.
    cov_back_to_back_ahandshakes: cover property (
        (a_valid && a_ready) ##1 (a_valid && a_ready)
    );

    // C6. The completion grant actually rotates from one outstanding ID to
    //     a different one, not just re-granting the same slot repeatedly.
    cov_grant_rotates_between_ids: cover property (
        (id_grant != '0) ##1 (id_grant != '0) && (id_grant != $past(id_grant))
    );

    // C7. Each slave's completion actually reaches the master at least once.
    generate
        for (genvar j = 0; j < SLV_NB; j++) begin : GEN_COV_SLAVE_ROUTED
            cov_completion_routed_per_slave_j: cover property (
                c_valid[j] ##[0:8] (|(id_grant) && c_grant[j])
            );
        end
    endgenerate

endmodule

`resetall
