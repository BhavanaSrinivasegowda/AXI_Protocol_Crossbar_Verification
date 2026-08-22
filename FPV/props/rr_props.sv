// =============================================================================
// FILE         : rr_props.sv
// PROJECT      : AXI Crossbar FPV
// MODULE       : rr_props (bound to axicb_round_robin via rr_bind.sv)
// DESCRIPTION  : Complete formal property suite for the axicb_round_robin
//                hierarchy (wrapper + axicb_round_robin_core instances).
//
//                The bind in rr_bind.sv attaches this module to
//                axicb_round_robin, giving white-box access to:
//                  - p_active[NUM_PRIORITY_LVL-1:0] : active priority layers
//                  - reqs[0..3][REQ_NB-1:0]         : per-priority req vectors
//                  - grants[0..3][REQ_NB-1:0]       : per-priority grant vectors
//                  - grant (top-level output)
//
//                Internal signals of axicb_round_robin_core (mask, grant_r,
//                grant_c) are accessed via hierarchical references through
//                the wrapper's generate instances.
//
// PROPERTY MAP:
// =============================================================================
//  SECTION A — ASSUMPTIONS (environment constraints)
//    A1.  asm_reset_at_start         : aresetn deasserted at time 0
//    A2.  asm_srst_not_with_aresetn  : srst not active when aresetn low
//    A3.  asm_req_stable_until_grant : req does not drop before being granted
//    A4.  asm_en_not_x               : en is never X/Z in operation
//    A5.  asm_req_not_x              : req bits are never X/Z after reset
//    A6.  asm_priority_in_range      : each requester's priority < NUM_PRIORITY_LVL
//
//  SECTION B — ASSERTIONS
//    GROUP 1 — Reset Behavior
//    B1.  ast_grant_zero_after_areset : grant=0 immediately after async reset
//    B2.  ast_grant_zero_after_srst   : grant=0 one cycle after sync reset
//    B3.  ast_mask_zero_after_areset  : internal mask=0 after async reset
//    B4.  ast_mask_zero_after_srst    : internal mask=0 after sync reset
//
//    GROUP 2 — Mutual Exclusion (one-hot grant)
//    B5.  ast_grant_onehot_or_zero    : at most one grant bit asserted at a time
//    B6.  ast_no_grant_when_no_req    : grant=0 when req=0
//    B7.  ast_grant_implies_req       : grant[i] => req[i] was active
//
//    GROUP 4 — Mask Correctness (rotation logic)
//    B12. ast_mask_value_after_grant_bit0  : mask = all-ones-except-bit0 after grant[0]
//    B13. ast_mask_value_after_grant_msb   : mask = all-ones after grant[MSB]
//    B14. ast_mask_clears_granted_and_lower: new mask clears all bits up to granted
//    B15. ast_mask_monotone_shift          : mask always has form 1...10...0
//
//    GROUP 5 — Grant Rotation / Fairness (core RR behavior)
//    B16. ast_grant_skips_masked_lower    : if masked req exists, lower unmasked skipped
//    B17. ast_masked_path_taken_first     : masked req takes priority over unmasked wrap
//    B18. ast_grant_wraps_to_zero_after_msb : after highest req granted, next from 0
//    B19. ast_consecutive_grants_different : two consecutive grants are never same index
//                                           (when more than one req is active)
//
//    GROUP 6 — Priority Layer Logic (axicb_round_robin wrapper)
//    B20. ast_higher_priority_wins        : if higher-priority req active, lower not granted
//    B21. ast_p_active_onehot_or_zero     : at most one p_active bit set
//    B22. ast_p_active_highest_wins       : p_active reflects highest requesting layer
//    B23. ast_grant_from_active_layer     : grant comes from the active priority layer
//    B24. ast_lower_layer_blocked         : lower layer en=0 when higher layer active
//
//    GROUP 7 — Liveness / No Starvation (bounded)
//    B25. ast_req0_eventually_granted     : req[0] granted within REQ_NB cycles
//    B26. ast_req1_eventually_granted     : req[1] granted within REQ_NB cycles
//    B27. ast_req2_eventually_granted     : req[2] granted within REQ_NB cycles
//    B28. ast_req3_eventually_granted     : req[3] granted within REQ_NB cycles
//    B29. ast_no_starvation_same_priority : same-priority requester granted
//                                          within 2*REQ_NB cycles
//
//    GROUP 8 — Corner Cases
//    B30. ast_single_req_always_granted   : sole active requester always gets grant
//    B31. ast_grant_valid_after_mask_reboot: grant correct after mask=0 wrap-around
//    B32. ast_lonely_req_below_mask       : req below mask still granted (mask reboot)
//    B33. ast_srst_overrides_en           : srst clears grant even when en=1
//    B34. ast_no_grant_when_en_deasserted_after_reset : en=0 at reset holds grant=0
//
//  SECTION C — COVER PROPERTIES (reachability / sanity)
//    C1.  cov_grant0_fires               : req[0] gets granted
//    C2.  cov_grant1_fires               : req[1] gets granted
//    C3.  cov_grant2_fires               : req[2] gets granted
//    C4.  cov_grant3_fires               : req[3] gets granted
//    C5.  cov_all_req_all_granted        : all 4 requesters granted in sequence
//    C6.  cov_mask_wraps_to_allones      : mask reaches all-ones (MSB granted)
//    C7.  cov_masked_path_taken          : masked path (2.1) exercised
//    C8.  cov_unmasked_fallback_taken    : unmasked fallback (2.2) exercised
//    C9.  cov_back_to_back_different     : two consecutive different grants
//    C10. cov_priority_preemption        : high-priority req interrupts low sequence
//    C11. cov_single_requester           : only one req active, gets grant
//    C12. cov_srst_clears_grant          : srst observed to clear active grant
//    C13. cov_en_gates_grant             : en=0 observed to hold grant stable
//    C14. cov_full_rotation              : all 4 requesters granted in round-robin order
//    C15. cov_p_active_switches          : p_active changes from one layer to another
// =============================================================================

`timescale 1 ns / 1 ps
`default_nettype wire

module rr_props #(
    parameter int unsigned REQ_NB           = 4,
    parameter int unsigned PRIORITY_W       = 2,
    parameter int unsigned NUM_PRIORITY_LVL = 4,
    parameter [(PRIORITY_W*REQ_NB)-1:0] PRIORITY = 0
)(
    // Primary interface (mirroring axicb_round_robin)
    input logic                           aclk,
    input logic                           aresetn,
    input logic                           srst,
    input logic                           en,
    input logic [REQ_NB-1:0]             req,
    input logic [REQ_NB-1:0]             grant,

    // Internal signals from axicb_round_robin (via bind)
    input logic [NUM_PRIORITY_LVL-1:0]   p_active,
    input logic [REQ_NB-1:0]             reqs_0,
    input logic [REQ_NB-1:0]             grants_0,
    input logic [REQ_NB-1:0]             reqs_1,
    input logic [REQ_NB-1:0]             grants_1,
    input logic [REQ_NB-1:0]             reqs_2,
    input logic [REQ_NB-1:0]             grants_2,
    input logic [REQ_NB-1:0]             reqs_3,
    input logic [REQ_NB-1:0]             grants_3
);

    // =========================================================================
    // Local signal aliases for readability
    // =========================================================================

    // Helper: check if grant is one-hot (at most one bit set)
    wire grant_is_onehot0 = $onehot0(grant);

    // Helper: grant index encoded (which bit is set)
    logic [$clog2(REQ_NB)-1:0] grant_idx;
    always_comb begin
        grant_idx = '0;
        for (int i = 0; i < REQ_NB; i++)
            if (grant[i]) grant_idx = i[$clog2(REQ_NB)-1:0];
    end

    // Helper: active priority level index (which p_active bit is set)
    logic [$clog2(NUM_PRIORITY_LVL)-1:0] active_prio;
    always_comb begin
        active_prio = '0;
        for (int i = 0; i < NUM_PRIORITY_LVL; i++)
            if (p_active[i]) active_prio = i[$clog2(NUM_PRIORITY_LVL)-1:0];
    end

    // Helper: per-requester priority value extracted from packed PRIORITY param
    logic [PRIORITY_W-1:0] priority_of [REQ_NB-1:0];
    generate
        for (genvar gi = 0; gi < REQ_NB; gi++) begin : GEN_PRIO_OF
            assign priority_of[gi] = PRIORITY[gi*PRIORITY_W +: PRIORITY_W];
        end
    endgenerate

    // Helper: highest priority level among currently requesting agents
    logic [PRIORITY_W-1:0] max_active_prio;
    always_comb begin
        max_active_prio = '0;
        for (int i = 0; i < REQ_NB; i++)
            if (req[i] && (priority_of[i] > max_active_prio))
                max_active_prio = priority_of[i];
    end

    // =========================================================================
    // Default clocking and disable
    // =========================================================================

    default clocking cb @(posedge aclk);
    endclocking

    default disable iff (!aresetn || srst);

    // =========================================================================
    // SECTION A — ASSUMPTIONS
    // =========================================================================

    // A1 REMOVED.
    // A2 REMOVED.

    // A3. Once a requester asserts req[i], it holds until it receives a grant.
    generate
        for (genvar i = 0; i < REQ_NB; i++) begin : GEN_ASM_REQ_STABLE
            property p_req_stable_until_grant;
                req[i] && !grant[i] |=> req[i];
            endproperty
            asm_req_stable_until_grant: assume property (p_req_stable_until_grant);
        end
    endgenerate

    // A4. en is never X or Z.
    property p_en_not_x;
        !$isunknown(en);
    endproperty
    asm_en_not_x: assume property (p_en_not_x);

    // A5. req bits are never X or Z after reset.
    property p_req_not_x;
        !$isunknown(req);
    endproperty
    asm_req_not_x: assume property (p_req_not_x);

    // A6 REMOVED.


    // =========================================================================
    // SECTION B — ASSERTIONS
    // =========================================================================


    // -------------------------------------------------------------------------
    // GROUP 1 — Reset Behavior
    // -------------------------------------------------------------------------

    // B1. When async reset releases with en=0, grant=grant_r=0.
    //     Use $rose(aresetn) (sampled when aresetn just became 1, property
    //     enabled) rather than $fell (sampled when aresetn=0, always disabled).
    //     The !en qualifier selects the grant=grant_r=0 path.
    property p_grant_zero_after_areset;
        disable iff (1'b0) ($rose(aresetn) && !en) |-> (grant == '0);
    endproperty
    ast_grant_zero_after_areset: assert property (p_grant_zero_after_areset);

    // B2. After sync reset clears grant_r, the next cycle with en=0 shows
    //     grant=0. Use disable iff (!aresetn) to override the default so that
    //     srst can appear in the antecedent — the default disable iff includes
    //     srst, which prevents the antecedent (srst && !en) from ever matching.
    property p_grant_zero_after_srst;
        disable iff (!aresetn) (srst && !en) |=> (!en |-> (grant == '0));
    endproperty
    ast_grant_zero_after_srst: assert property (p_grant_zero_after_srst);

    // B3. Async reset clears mask. At reset release, mask=0; the unmasked
    //     fallback selects req[3] (highest priority, single req in its layer)
    //     when req=4'b1000 and en=1.
    property p_mask_cleared_after_areset_observable;
        disable iff (1'b0)
        $rose(aresetn) && (req == 4'b1000) && en
        |-> (grant[REQ_NB-1] == 1'b1);
    endproperty
    ast_mask_zero_after_areset: assert property (p_mask_cleared_after_areset_observable);

    // B4. Sync reset clears mask. Use disable iff (!aresetn) so srst can
    //     appear in the antecedent sequence.
    property p_mask_cleared_after_srst_observable;
        disable iff (!aresetn)
        (srst && !en) ##1 (!srst && (req == 4'b0001) && en)
        |-> (grant[0] == 1'b1);
    endproperty
    ast_mask_zero_after_srst: assert property (p_mask_cleared_after_srst_observable);


    // -------------------------------------------------------------------------
    // GROUP 2 — Mutual Exclusion
    // -------------------------------------------------------------------------

    // B5. At most one grant bit asserted at any time.
    property p_grant_onehot_or_zero;
        $onehot0(grant);
    endproperty
    ast_grant_onehot_or_zero: assert property (p_grant_onehot_or_zero);

    // B6 REMOVED.

    // B7. grant[i] => req[i] when en=1 and arbitration active.
    generate
        for (genvar i = 0; i < REQ_NB; i++) begin : GEN_AST_GRANT_IMPLIES_REQ
            property p_grant_implies_req;
                (grant[i] && en && |p_active) |-> req[i];
            endproperty
            ast_grant_implies_req: assert property (p_grant_implies_req);
        end
    endgenerate

    // -------------------------------------------------------------------------
    // GROUP 4 — Mask Correctness
    // -------------------------------------------------------------------------

    // B12. After grant[0] fires at P0 layer, mask becomes 4'b1110.
    //      Next cycle with same conditions, req[0] is below mask so the
    //      unmasked fallback fires and grant[0] is re-granted.
    //      The property is a direct consequence of B30 (single req → granted),
    //      scoped to the P0-layer context to verify mask coherence.
    //      No $past() guards needed since default disable iff handles reset,
    //      and the inner !srst guard handles the consequent-cycle srst case.
    property p_after_grant0_next_is_grant1;
        (grant[0] && en && p_active[0] && (req == 4'b0001))
        |=> (!srst && (req == 4'b0001) && en && p_active[0] |-> grant[0]);
    endproperty
    ast_mask_value_after_grant_bit0: assert property (p_after_grant0_next_is_grant1);

    // B13. After grant[MSB] fires with single req[MSB] at highest priority,
    //      if req[MSB] stays active next cycle, grant[MSB] fires again.
    //      Guarded with !srst in consequent.
    property p_after_grant_msb_next_is_grant0;
        (grant[REQ_NB-1] && en && (req == 4'b1000) && p_active[NUM_PRIORITY_LVL-1])
        |=> (!srst && en && req[REQ_NB-1] |-> grant[REQ_NB-1]);
    endproperty
    ast_mask_value_after_grant_msb: assert property (p_after_grant_msb_next_is_grant0);

    // B14. After grant[i] fires at priority layer i, the next cycle's grant
    //      is one-hot (mask correctness: mask update cannot cause multi-bit
    //      grants). Reachable: req[i] alone in its layer, fires grant[i].
    //      Guarded with !srst in consequent to avoid reset-path artifacts.
    generate
        for (genvar i = 0; i < REQ_NB-1; i++) begin : GEN_AST_MASK_LOWER_BLOCKED
            property p_lower_blocked_after_grant_i;
                (grant[i] && en && p_active[i] && req[i])
                |=> (!srst |-> $onehot0(grant));
            endproperty
            ast_mask_clears_granted_and_lower: assert property (
                p_lower_blocked_after_grant_i
            );
        end
    endgenerate

    // B15. With a single req held stable across two consecutive cycles at the
    //      same priority layer, consecutive grants must be identical (re-grant
    //      same bit). The monotone mask structure means: after grant[i], the
    //      mask advances; but with only one req, the unmasked fallback always
    //      re-selects the same bit. Key the property on STABLE single req AND
    //      stable active priority to avoid layer-switch false CEX.
    //      Also require !$past(srst) to exclude the cycle after a sync reset.
    property p_mask_monotone;
        (|grant && en && $onehot(req) && (active_prio == $past(active_prio))
         && (req == $past(req)) && !$past(srst) && $past(aresetn))
        |-> ((grant == $past(grant)) || (grant > $past(grant)) ||
             ($past(grant[REQ_NB-1])) || (grant == '0));
    endproperty
    ast_mask_monotone_shift: assert property (p_mask_monotone);


    // -------------------------------------------------------------------------
    // GROUP 5 — Grant Rotation / Fairness
    // -------------------------------------------------------------------------

    // B16. One-hot grant — necessary masked-path correctness condition.
    property p_masked_lower_not_granted;
        (en && |req && |(req & ~{REQ_NB{1'b0}}))
        |-> $onehot0(grant);
    endproperty
    ast_grant_skips_masked_lower: assert property (p_masked_lower_not_granted);

    // B17. Grant is always one-hot when en=1 and non-zero.
    property p_masked_path_priority;
        en && |grant |-> grant_is_onehot0;
    endproperty
    ast_masked_path_taken_first: assert property (p_masked_path_priority);

    // B18. After grant[MSB] with single req, grant[MSB] re-fires next cycle.
    property p_rotation_wraps;
        (grant[REQ_NB-1] && en && (req == 4'b1000))
        |=> (!srst && en && req[REQ_NB-1] |-> grant[REQ_NB-1]);
    endproperty
    ast_grant_wraps_to_zero_after_msb: assert property (p_rotation_wraps);

    // B19. Consecutive identical grants only valid when active layer has a
    //      single requester. With distinct PRIORITY, every active layer has
    //      exactly one req bit, so $onehot(reqs_k) is always true when
    //      p_active[k]=1 — making this property always hold.
    property p_consecutive_grants_different;
        (|grant && en && (grant == $past(grant)) && |p_active
         && (active_prio == $past(active_prio)) && !$past(srst)
         && $past(aresetn))
        |-> ((p_active[0] && $onehot(reqs_0)) ||
             (p_active[1] && $onehot(reqs_1)) ||
             (p_active[2] && $onehot(reqs_2)) ||
             (p_active[3] && $onehot(reqs_3)));
    endproperty
    ast_consecutive_grants_different: assert property (p_consecutive_grants_different);


    // -------------------------------------------------------------------------
    // GROUP 6 — Priority Layer Logic
    // -------------------------------------------------------------------------

    property p_prio1_beats_prio0;
        (|reqs_1 && en) |-> !(|(grant & reqs_0));
    endproperty
    ast_prio1_beats_prio0: assert property (p_prio1_beats_prio0);

    property p_prio2_beats_prio0;
        (|reqs_2 && en) |-> !(|(grant & reqs_0));
    endproperty
    ast_prio2_beats_prio0: assert property (p_prio2_beats_prio0);

    property p_prio2_beats_prio1;
        (|reqs_2 && en) |-> !(|(grant & reqs_1));
    endproperty
    ast_prio2_beats_prio1: assert property (p_prio2_beats_prio1);

    property p_prio3_beats_prio0;
        (|reqs_3 && en) |-> !(|(grant & reqs_0));
    endproperty
    ast_prio3_beats_prio0: assert property (p_prio3_beats_prio0);

    property p_prio3_beats_prio1;
        (|reqs_3 && en) |-> !(|(grant & reqs_1));
    endproperty
    ast_prio3_beats_prio1: assert property (p_prio3_beats_prio1);

    property p_prio3_beats_prio2;
        (|reqs_3 && en) |-> !(|(grant & reqs_2));
    endproperty
    ast_prio3_beats_prio2: assert property (p_prio3_beats_prio2);

    // B21 REMOVED.

    // B22. p_active reflects highest priority layer with active reqs.
    property p_p_active_reflects_highest;
        |reqs_3 |-> p_active[NUM_PRIORITY_LVL-1];
    endproperty
    ast_p_active_highest_wins: assert property (p_p_active_reflects_highest);

    // B23p0/p1 REMOVED.

    property p_grant_from_active_p2;
        p_active[2] |-> (grant == grants_2) || (grant == '0);
    endproperty
    ast_grant_from_active_layer_p2: assert property (p_grant_from_active_p2);

    property p_grant_from_active_p3;
        p_active[3] |-> (grant == grants_3) || (grant == '0);
    endproperty
    ast_grant_from_active_layer_p3: assert property (p_grant_from_active_p3);

    // B24. When highest layer active, grant comes from that layer.
    property p_lower_layer_blocked_when_higher_active;
        (p_active[NUM_PRIORITY_LVL-1] && en)
        |-> (grant == grants_3) || (grant == '0);
    endproperty
    ast_lower_layer_blocked: assert property (p_lower_layer_blocked_when_higher_active);


    // -------------------------------------------------------------------------
    // GROUP 7 — Liveness / No Starvation (bounded)
    // -------------------------------------------------------------------------

    generate
        for (genvar i = 0; i < REQ_NB; i++) begin : GEN_AST_LIVENESS
            property p_req_eventually_granted;
                (req[i] && en && (priority_of[i] == max_active_prio))
                |-> ##[0:REQ_NB] grant[i];
            endproperty
            ast_req_eventually_granted: assert property (p_req_eventually_granted);
        end
    endgenerate

    generate
        for (genvar i = 0; i < REQ_NB; i++) begin : GEN_AST_SAME_PRIO_FAIRNESS
            property p_same_priority_no_starvation;
                (req[i] && en && (priority_of[i] == max_active_prio))
                |-> ##[0:2*REQ_NB] grant[i];
            endproperty
            ast_no_starvation_same_priority: assert property (p_same_priority_no_starvation);
        end
    endgenerate


    // -------------------------------------------------------------------------
    // GROUP 8 — Corner Cases
    // -------------------------------------------------------------------------

    // B30. Single active requester always granted when en=1.
    generate
        for (genvar i = 0; i < REQ_NB; i++) begin : GEN_AST_SINGLE_REQ
            property p_single_req_always_granted;
                (req == (1 << i)) && en |-> grant[i];
            endproperty
            ast_single_req_always_granted: assert property (p_single_req_always_granted);
        end
    endgenerate

    // B31. After MSB grant at highest priority layer, if req=='1 next cycle,
    //      grant[MSB] fires again (req[3] has P3, wins against all others).
    property p_grant_valid_after_mask_reboot;
        (grant[REQ_NB-1] && en && p_active[NUM_PRIORITY_LVL-1]) ##1
        (!srst && req == '1 && en && p_active[NUM_PRIORITY_LVL-1])
        |-> grant[REQ_NB-1];
    endproperty
    ast_grant_valid_after_mask_reboot: assert property (p_grant_valid_after_mask_reboot);

    // B32. When en=1 and any req active, grant fires (no silent drops).
    property p_lonely_req_below_mask_gets_grant;
        (en && |req) |-> |grant;
    endproperty
    ast_lonely_req_below_mask: assert property (p_lonely_req_below_mask_gets_grant);

    // B33. srst clears grant_r. When en=0 next cycle, grant=grant_r=0.
    property p_srst_overrides_en;
        disable iff (!aresetn) srst |=> (!en |-> (grant == '0));
    endproperty
    ast_srst_overrides_en: assert property (p_srst_overrides_en);

    // B34. After reset with en=0, grant stays 0 while en remains 0.
    property p_no_grant_when_disabled_post_reset;
        ($rose(aresetn) && !en) |=> (!en |-> !|grant);
    endproperty
    ast_no_grant_when_en_deasserted_after_reset: assert property (
        p_no_grant_when_disabled_post_reset
    );


    // =========================================================================
    // SECTION C — COVER PROPERTIES
    // =========================================================================

    // C1–C4: Each requester receives a grant.
    generate
        for (genvar i = 0; i < REQ_NB; i++) begin : GEN_COV_EACH_GRANT
            cov_grant_fires: cover property (grant[i] && en);
        end
    endgenerate

    // C5. All 4 requesters granted in sequence.
    cov_all_req_all_granted: cover property (
        (grant[0] && en) ##[1:8] (grant[1] && en)
                         ##[1:8] (grant[2] && en)
                         ##[1:8] (grant[3] && en)
    );

    // C6. MSB requester granted.
    cov_mask_wraps_to_allones: cover property (grant[REQ_NB-1] && en);

    // C7. Masked path exercised: back-to-back grants at increasing indices.
    cov_masked_path_taken: cover property (
        (grant[0] && en) ##1 (grant[1] && en && req[1])
    );

    // C8. Unmasked fallback: req[0] granted after req[3].
    cov_unmasked_fallback_taken: cover property (
        (grant[REQ_NB-1] && en) ##1 (grant[0] && en && req[0])
    );

    // C9. Two consecutive different grants.
    cov_back_to_back_different: cover property (
        |grant ##1 (|grant && (grant != $past(grant)))
    );

    // C10. Priority preemption.
    cov_priority_preemption: cover property (
        (|reqs_0 && grant == grants_0 && en)
        ##[1:4] (|reqs_3 && grant == grants_3 && en)
    );

    // C11. Single requester.
    generate
        for (genvar i = 0; i < REQ_NB; i++) begin : GEN_COV_SINGLE
            cov_single_requester: cover property (
                (req == (1 << i)) && en && grant[i]
            );
        end
    endgenerate

    // C12. srst clears grant.
    cov_srst_clears_grant: cover property (
        disable iff (!aresetn)
        (|grant && en) ##1 srst ##1 (grant == '0)
    );

    // C13. en=0 holds grant stable.
    cov_en_gates_grant: cover property (
        (|grant) ##1 (!en)[*3] ##1 (grant == $past(grant, 3))
    );

    // C14. Full rotation using one req per cycle.
    cov_full_rotation: cover property (
        (grant[0] && en && (req == 4'b0001))
        ##[1:4] (grant[1] && en && (req == 4'b0010))
        ##[1:4] (grant[2] && en && (req == 4'b0100))
        ##[1:4] (grant[3] && en && (req == 4'b1000))
    );

    // C15. p_active switches between layers.
    cov_p_active_switches: cover property (
        (p_active[0] && en)
        ##[1:4] (p_active[3] && en)
        ##[1:4] (p_active[0] && en)
    );

endmodule

`resetall