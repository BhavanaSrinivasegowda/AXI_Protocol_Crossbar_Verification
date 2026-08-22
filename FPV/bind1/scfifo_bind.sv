// =============================================================================
// FILE         : scfifo_bind.sv
// PROJECT      : AXI Crossbar FPV
// DESCRIPTION  : Bind file attaching scfifo_props to axicb_scfifo.
//                Exposes wrptr, rdptr, empty_flag and full_flag — all
//                declared directly in axicb_scfifo (not nested inside the
//                RAM/REGFILE generate block) — for white-box pointer and
//                flag-correctness properties.
//                No DUT source modification required.
// TOOL         : JasperGold Formal Property Verification
// =============================================================================

`timescale 1 ns / 1 ps
`default_nettype none

bind axicb_scfifo scfifo_props #(
    .BLOCK      (BLOCK),
    .PASS_THRU  (PASS_THRU),
    .ADDR_WIDTH (ADDR_WIDTH),
    .DATA_WIDTH (DATA_WIDTH)
) u_scfifo_props (

    // -------------------------------------------------------------------------
    // Primary interface — mirrors axicb_scfifo port list exactly
    // -------------------------------------------------------------------------
    .aclk       (aclk),
    .aresetn    (aresetn),
    .srst       (srst),
    .flush      (flush),
    .data_in    (data_in),
    .push       (push),
    .full       (full),
    .data_out   (data_out),
    .pull       (pull),
    .empty      (empty),

    // -------------------------------------------------------------------------
    // Internal signals from axicb_scfifo — accessible via bind scope
    // Used for white-box assertions on pointer/flag correctness
    // -------------------------------------------------------------------------
    .wrptr      (wrptr),
    .rdptr      (rdptr),
    .empty_flag (empty_flag),
    .full_flag  (full_flag)
);

`resetall
