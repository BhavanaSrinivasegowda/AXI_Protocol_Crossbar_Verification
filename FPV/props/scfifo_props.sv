// =============================================================================
// FILE         : scfifo_props.sv
// PROJECT      : AXI Crossbar FPV
// MODULE       : scfifo_props (bound to axicb_scfifo via scfifo_bind.sv)
// DESCRIPTION  : Standalone formal property suite for axicb_scfifo, the
//                generic single-clock FIFO reused throughout the crossbar
//                (AW/W/B/AR/R channel buffers in axicb_mst_if/axicb_slv_if,
//                wch_gnt_fifo in axicb_mst_switch_wr/axicb_slv_switch_wr,
//                id_fifo in axicb_slv_ooo).
//
//                DUT is verified as a standalone unit: push, pull, data_in,
//                flush and srst are left completely free (no crossbar-level
//                constraints) so the proof covers every legal and illegal
//                sequence a caller could apply.
//
//                FIRST PASS SCOPE (see scfifo_fpv_top.sv):
//                  BLOCK = "RAM", PASS_THRU = 0  (STORE_MODE only).
//                  BLOCK = "REGFILE" and PASS_THRU = 1 are left as future
//                  work — properties below are commented where the port-
//                  level equivalences (B6/B7) are specific to PASS_THRU=0.
//
//                The bind in scfifo_bind.sv attaches this module to
//                axicb_scfifo, giving white-box access to:
//                  - wrptr, rdptr           : write/read pointers (ADDR_WIDTH+1 bits)
//                  - empty_flag, full_flag  : internal flags computed from the pointers
//
// PROPERTY MAP:
// =============================================================================
//  SECTION A — ASSUMPTIONS (environment legality only — kept minimal so a
//              real overflow/underflow/data bug cannot be masked)
//    A1. asm_ctrl_not_x     : push/pull/srst/flush are never X/Z
//    A2. asm_data_in_not_x  : data_in is known whenever a push is attempted
//
//  SECTION B — ASSERTIONS
//    GROUP 1 — Reset Behavior
//    B1.  ast_ptrs_zero_after_areset  : wrptr=rdptr=0 immediately after async reset
//    B2.  ast_ptrs_zero_after_srst    : wrptr=rdptr=0 one cycle after sync reset
//    B3.  ast_ptrs_zero_after_flush   : wrptr=rdptr=0 one cycle after flush
//
//    GROUP 2 — Flag Correctness
//    B4.  ast_empty_flag_matches_ptrs   : empty_flag <=> (wrptr==rdptr)
//    B5.  ast_full_flag_matches_ptrs    : full_flag  <=> ((wrptr-rdptr)==DEPTH)
//    B6.  ast_port_empty_matches_internal : empty == empty_flag (PASS_THRU=0 only)
//    B7.  ast_port_full_matches_internal  : full  == full_flag  (PASS_THRU=0 only)
//    B8.  ast_full_empty_mutually_exclusive : never full and empty at once
//
//    GROUP 3 — Overflow / Underflow Protection
//    B9.  ast_no_overflow   : push into a full FIFO never advances wrptr
//    B10. ast_no_underflow  : pull from an empty FIFO never advances rdptr
//
//    GROUP 4 — Pointer / Wrap-Around Correctness
//    B11. ast_wrptr_increments_on_push   : legal push advances wrptr by 1
//    B12. ast_wrptr_stable_unless_push   : wrptr never moves otherwise
//    B13. ast_rdptr_increments_on_pull   : legal pull advances rdptr by 1
//    B14. ast_rdptr_stable_unless_pull   : rdptr never moves otherwise
//    B15. ast_occupancy_never_exceeds_depth : (wrptr-rdptr) <= DEPTH always
//    B16. ast_wrptr_msb_wrap_toggle : extra MSB bit flips exactly when the
//                                     low ADDR_WIDTH bits of wrptr wrap
//    B17. ast_rdptr_msb_wrap_toggle : same, for rdptr
//
//    GROUP 5 — Data Integrity (FIFO ordering)
//    B18. ast_data_integrity            : front-of-queue value always matches
//                                          what was actually written to that
//                                          slot (shadow-memory scoreboard)
//    B19. ast_front_stable_until_popped : data_out doesn't drift while the
//                                          front entry hasn't been popped
//
//  SECTION C — COVER PROPERTIES (reachability / sanity)
//    C1. cov_fifo_reaches_full   : FIFO fills completely
//    C2. cov_empty_after_full    : FIFO drains from full back to empty
//    C3. cov_wrptr_wraps         : write pointer wraps around the buffer
//    C4. cov_rdptr_wraps         : read pointer wraps around the buffer
// =============================================================================

`timescale 1 ns / 1 ps
`default_nettype wire

module scfifo_props #(
    parameter                     BLOCK      = "RAM",
    parameter                     PASS_THRU  = 0,
    parameter int unsigned        ADDR_WIDTH = 2,
    parameter int unsigned        DATA_WIDTH = 8
)(
    // Primary interface (mirroring axicb_scfifo)
    input logic                    aclk,
    input logic                    aresetn,
    input logic                    srst,
    input logic                    flush,
    input logic [DATA_WIDTH-1:0]   data_in,
    input logic                    push,
    input logic                    full,
    input logic [DATA_WIDTH-1:0]   data_out,
    input logic                    pull,
    input logic                    empty,

    // Internal signals from axicb_scfifo (via bind)
    input logic [ADDR_WIDTH:0]     wrptr,
    input logic [ADDR_WIDTH:0]     rdptr,
    input logic                    empty_flag,
    input logic                    full_flag
);

    // =========================================================================
    // Local helpers
    // =========================================================================

    // Depth expressed with the same extra-bit encoding the RTL uses for its
    // full-flag comparison: a 1 in the MSB, zeros below == 2**ADDR_WIDTH.
    localparam logic [ADDR_WIDTH:0] DEPTH = {1'b1, {ADDR_WIDTH{1'b0}}};

    // Reference model: mirrors the RTL's own write (wr_en = push & ~full,
    // PASS_THRU=0) so B18/B19 can check the DUT's actual data_out against
    // an independently-held copy of what was written to each slot.
    logic [DATA_WIDTH-1:0] shadow_mem [0:(2**ADDR_WIDTH)-1];

    always_ff @(posedge aclk) begin
        if (push && !full) begin
            shadow_mem[wrptr[ADDR_WIDTH-1:0]] <= data_in;
        end
    end

    // =========================================================================
    // Default clocking and disable
    // =========================================================================

    default clocking cb @(posedge aclk);
    endclocking

    // flush behaves like srst (both synchronously clear wrptr/rdptr), so it
    // is folded into the default disable alongside aresetn/srst.
    default disable iff (!aresetn || srst || flush);

    // =========================================================================
    // SECTION A — ASSUMPTIONS
    // =========================================================================

    // A1. Control signals are never X/Z. Needed so the shadow-memory write
    //     condition (push && !full) and the flag comparisons below are
    //     always well-defined — this does not restrict push/pull sequencing.
    property p_ctrl_not_x;
        !$isunknown({push, pull, srst, flush});
    endproperty
    asm_ctrl_not_x: assume property (p_ctrl_not_x);

    // A2. data_in only needs to be known at the moment it is actually
    //     pushed — an unknown data_in when push=0 is harmless and left
    //     unconstrained.
    property p_data_in_not_x;
        push |-> !$isunknown(data_in);
    endproperty
    asm_data_in_not_x: assume property (p_data_in_not_x);


    // =========================================================================
    // SECTION B — ASSERTIONS
    // =========================================================================

    // -------------------------------------------------------------------------
    // GROUP 1 — Reset Behavior
    // -------------------------------------------------------------------------

    // B1. Async reset forces both pointers to 0. Override disable to (1'b0)
    //     so the check still fires even if srst/flush happen to be asserted
    //     in the same cycle aresetn releases (mirrors rr_props B1 idiom).
    property p_ptrs_zero_after_areset;
        disable iff (1'b0)
        $rose(aresetn) |-> (wrptr == '0 && rdptr == '0);
    endproperty
    ast_ptrs_zero_after_areset: assert property (p_ptrs_zero_after_areset);

    // B2. Sync reset clears both pointers one cycle later. Override disable
    //     to (!aresetn) only, since the default disable (which includes
    //     srst) would otherwise prevent srst from ever appearing in the
    //     antecedent.
    property p_ptrs_zero_after_srst;
        disable iff (!aresetn)
        srst |=> (wrptr == '0 && rdptr == '0);
    endproperty
    ast_ptrs_zero_after_srst: assert property (p_ptrs_zero_after_srst);

    // B3. flush has the same effect as srst on the pointers.
    property p_ptrs_zero_after_flush;
        disable iff (!aresetn)
        flush |=> (wrptr == '0 && rdptr == '0);
    endproperty
    ast_ptrs_zero_after_flush: assert property (p_ptrs_zero_after_flush);


    // -------------------------------------------------------------------------
    // GROUP 2 — Flag Correctness
    // -------------------------------------------------------------------------

    // B4. Internal empty flag is exactly "pointers equal" — true regardless
    //     of PASS_THRU/BLOCK since it is the RTL's raw combinational def.
    property p_empty_flag_matches_ptrs;
        empty_flag == (wrptr == rdptr);
    endproperty
    ast_empty_flag_matches_ptrs: assert property (p_empty_flag_matches_ptrs);

    // B5. Internal full flag is exactly "occupancy == DEPTH".
    property p_full_flag_matches_ptrs;
        full_flag == ((wrptr - rdptr) == DEPTH);
    endproperty
    ast_full_flag_matches_ptrs: assert property (p_full_flag_matches_ptrs);

    // B6. With PASS_THRU=0 (STORE_MODE), the port directly mirrors the
    //     internal flag. NOTE: this equivalence breaks once PASS_THRU=1 is
    //     enabled (empty becomes ~push during pass-thru) — revisit then.
    property p_port_empty_matches_internal;
        empty == empty_flag;
    endproperty
    ast_port_empty_matches_internal: assert property (p_port_empty_matches_internal);

    // B7. Same for full — holds unconditionally in STORE_MODE.
    property p_port_full_matches_internal;
        full == full_flag;
    endproperty
    ast_port_full_matches_internal: assert property (p_port_full_matches_internal);

    // B8. A FIFO with DEPTH>=1 can never be simultaneously full and empty
    //     (full requires the extra bit to differ, empty requires the full
    //     pointer, including that bit, to match).
    property p_full_empty_mutually_exclusive;
        !(empty_flag && full_flag);
    endproperty
    ast_full_empty_mutually_exclusive: assert property (p_full_empty_mutually_exclusive);


    // -------------------------------------------------------------------------
    // GROUP 3 — Overflow / Underflow Protection
    // -------------------------------------------------------------------------

    // B9. Attempting to push into a full FIFO must never move wrptr — the
    //     write is silently dropped, it does not corrupt/overflow storage.
    property p_no_overflow;
        (push && full) |=> (wrptr == $past(wrptr));
    endproperty
    ast_no_overflow: assert property (p_no_overflow);

    // B10. Attempting to pull from an empty FIFO must never move rdptr.
    property p_no_underflow;
        (pull && empty) |=> (rdptr == $past(rdptr));
    endproperty
    ast_no_underflow: assert property (p_no_underflow);


    // -------------------------------------------------------------------------
    // GROUP 4 — Pointer / Wrap-Around Correctness
    // -------------------------------------------------------------------------

    // B11. A legal push (not full) advances wrptr by exactly 1.
    property p_wrptr_increments_on_push;
        (push && !full) |=> (wrptr == ($past(wrptr) + 1'b1));
    endproperty
    ast_wrptr_increments_on_push: assert property (p_wrptr_increments_on_push);

    // B12. wrptr never moves except on a legal push (converse of B11).
    property p_wrptr_stable_unless_push;
        !(push && !full) |=> (wrptr == $past(wrptr));
    endproperty
    ast_wrptr_stable_unless_push: assert property (p_wrptr_stable_unless_push);

    // B13. A legal pull (not empty) advances rdptr by exactly 1.
    property p_rdptr_increments_on_pull;
        (pull && !empty) |=> (rdptr == ($past(rdptr) + 1'b1));
    endproperty
    ast_rdptr_increments_on_pull: assert property (p_rdptr_increments_on_pull);

    // B14. rdptr never moves except on a legal pull (converse of B13).
    property p_rdptr_stable_unless_pull;
        !(pull && !empty) |=> (rdptr == $past(rdptr));
    endproperty
    ast_rdptr_stable_unless_pull: assert property (p_rdptr_stable_unless_pull);

    // B15. Occupancy (wrptr-rdptr, computed mod 2**(ADDR_WIDTH+1) exactly as
    //      the RTL does) never exceeds DEPTH — the core safety net for the
    //      whole extra-bit pointer scheme across repeated wraps.
    property p_occupancy_never_exceeds_depth;
        (wrptr - rdptr) <= DEPTH;
    endproperty
    ast_occupancy_never_exceeds_depth: assert property (p_occupancy_never_exceeds_depth);

    // B16. The extra MSB bit is what lets empty/full be told apart once the
    //      low ADDR_WIDTH bits wrap. Check it actually flips exactly when
    //      the low bits roll over from all-ones to 0 on a push.
    property p_wrptr_msb_wrap_toggle;
        (push && !full && (wrptr[ADDR_WIDTH-1:0] == {ADDR_WIDTH{1'b1}}))
        |=> (wrptr[ADDR_WIDTH-1:0] == '0) &&
            (wrptr[ADDR_WIDTH] == !$past(wrptr[ADDR_WIDTH]));
    endproperty
    ast_wrptr_msb_wrap_toggle: assert property (p_wrptr_msb_wrap_toggle);

    // B17. Same wrap-toggle check for rdptr.
    property p_rdptr_msb_wrap_toggle;
        (pull && !empty && (rdptr[ADDR_WIDTH-1:0] == {ADDR_WIDTH{1'b1}}))
        |=> (rdptr[ADDR_WIDTH-1:0] == '0) &&
            (rdptr[ADDR_WIDTH] == !$past(rdptr[ADDR_WIDTH]));
    endproperty
    ast_rdptr_msb_wrap_toggle: assert property (p_rdptr_msb_wrap_toggle);


    // -------------------------------------------------------------------------
    // GROUP 5 — Data Integrity (FIFO ordering)
    // -------------------------------------------------------------------------

    // B18. Whenever the FIFO is non-empty, the value on data_out must equal
    //      what was actually written (by the RTL's own push/wrptr signals)
    //      to the slot rdptr currently points to. shadow_mem is a reference
    //      model built purely from ports + white-boxed pointers — it never
    //      touches the DUT's RAM instance, so this checks that the RAM's
    //      real read/write behavior matches what the pointer logic implies.
    property p_data_integrity;
        !empty |-> (data_out == shadow_mem[rdptr[ADDR_WIDTH-1:0]]);
    endproperty
    ast_data_integrity: assert property (p_data_integrity);

    // B19. As long as the front entry hasn't been popped, data_out must not
    //      drift — a push elsewhere in the buffer (different address, since
    //      wrptr/rdptr low bits can only coincide at empty or full) must not
    //      disturb the value currently being presented at the output.
    property p_front_stable_until_popped;
        ($past(!empty) && !$past(pull)) |=> (data_out == $past(data_out));
    endproperty
    ast_front_stable_until_popped: assert property (p_front_stable_until_popped);


    // =========================================================================
    // SECTION C — COVER PROPERTIES
    // =========================================================================

    // C1. The FIFO can actually fill up completely.
    cov_fifo_reaches_full: cover property (full);

    // C2. The FIFO can drain all the way back to empty after being full.
    cov_empty_after_full: cover property (full ##[1:32] empty);

    // C3. The write pointer's extra bit toggles — i.e. wrptr wraps around
    //     the physical buffer at least once.
    cov_wrptr_wraps: cover property (
        wrptr[ADDR_WIDTH] != $past(wrptr[ADDR_WIDTH])
    );

    // C4. Same wrap-around reachability for the read pointer.
    cov_rdptr_wraps: cover property (
        rdptr[ADDR_WIDTH] != $past(rdptr[ADDR_WIDTH])
    );

endmodule

`resetall
