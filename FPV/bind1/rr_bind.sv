// =============================================================================
// FILE         : rr_bind.sv
// PROJECT      : AXI Crossbar FPV
// DESCRIPTION  : Bind file attaching rr_props to axicb_round_robin.
//                Binds at the WRAPPER level so properties cover the full
//                hierarchy — priority sorting, p_active computation, and
//                the underlying axicb_round_robin_core instances.
//                No DUT source modification required.
// TOOL         : JasperGold Formal Property Verification
// =============================================================================

`timescale 1 ns / 1 ps
`default_nettype none

bind axicb_round_robin rr_props #(
    .REQ_NB           (REQ_NB),
    .PRIORITY_W       (PRIORITY_W),
    .NUM_PRIORITY_LVL (NUM_PRIORITY_LVL),
    .PRIORITY         (PRIORITY)
) u_rr_props (

    // -------------------------------------------------------------------------
    // Primary interface — mirrors axicb_round_robin port list exactly
    // -------------------------------------------------------------------------
    .aclk     (aclk),
    .aresetn  (aresetn),
    .srst     (srst),
    .en       (en),
    .req      (req),
    .grant    (grant),

    // -------------------------------------------------------------------------
    // Internal signals from axicb_round_robin — accessible via bind scope
    // Used for white-box assertions on priority logic
    // -------------------------------------------------------------------------
    .p_active (p_active),    // which priority layer is currently active
    .reqs_0   (reqs[0]),     // requesters filtered to priority level 0
    .grants_0 (grants[0]),   // grant output from priority level 0 core

    // NOTE: reqs[1..3] and grants[1..3] are conditionally accessed in
    // the properties file using generate guards on NUM_PRIORITY_LVL.
    // Bind only wires priority level 0 unconditionally; higher levels
    // are wired inside rr_props using generate blocks.
    .reqs_1   (reqs[1]),
    .grants_1 (grants[1]),
    .reqs_2   (reqs[2]),
    .grants_2 (grants[2]),
    .reqs_3   (reqs[3]),
    .grants_3 (grants[3])
);

`resetall
