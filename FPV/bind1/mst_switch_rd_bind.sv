// =============================================================================
// FILE         : mst_switch_rd_bind.sv
// PROJECT      : AXI Crossbar FPV
// DESCRIPTION  : Bind file attaching mst_switch_rd_props to
//                axicb_mst_switch_rd. Exposes both port-level AXI signals
//                and internal signals (AR grant, arbiter enable, R-targeting)
//                needed for white-box AXI protocol and routing properties.
//                No DUT source modification required.
// TOOL         : JasperGold Formal Property Verification
// =============================================================================

`timescale 1 ns / 1 ps
`default_nettype none

bind axicb_mst_switch_rd mst_switch_rd_props #(
    .AXI_ID_W         (AXI_ID_W),
    .AXI_DATA_W       (AXI_DATA_W),
    .MST_NB           (MST_NB),
    .NUM_PRIORITY_LVL (NUM_PRIORITY_LVL),
    .TIMEOUT_ENABLE   (TIMEOUT_ENABLE),
    .MST_ID_MASK      (MST_ID_MASK),
    .PRIORITY_W       (PRIORITY_W),
    .MST_PRIORITY     (MST_PRIORITY),
    .AWCH_W           (AWCH_W),
    .WCH_W            (WCH_W),
    .BCH_W            (BCH_W),
    .ARCH_W           (ARCH_W),
    .RCH_W            (RCH_W)
) u_mst_switch_rd_props (

    // -------------------------------------------------------------------------
    // Global interface
    // -------------------------------------------------------------------------
    .aclk               (aclk),
    .aresetn            (aresetn),
    .srst               (srst),

    // -------------------------------------------------------------------------
    // AXI Read Address Channel — Master side (input to switch)
    // -------------------------------------------------------------------------
    .i_arvalid          (i_arvalid),
    .i_arready          (i_arready),
    .i_arch             (i_arch),

    // -------------------------------------------------------------------------
    // AXI Read Data Channel — Master side (output from switch)
    // -------------------------------------------------------------------------
    .i_rvalid           (i_rvalid),
    .i_rready           (i_rready),
    .i_rlast            (i_rlast),
    .i_rch              (i_rch),

    // -------------------------------------------------------------------------
    // AXI Read Address Channel — Slave side (output from switch)
    // -------------------------------------------------------------------------
    .o_arvalid          (o_arvalid),
    .o_arready          (o_arready),
    .o_arch             (o_arch),

    // -------------------------------------------------------------------------
    // AXI Read Data Channel — Slave side (input to switch)
    // -------------------------------------------------------------------------
    .o_rvalid           (o_rvalid),
    .o_rready           (o_rready),
    .o_rlast            (o_rlast),
    .o_rch              (o_rch),

    // -------------------------------------------------------------------------
    // Internal signals — white-box access via bind scope
    // -------------------------------------------------------------------------

    // AR channel arbitration internals
    .arch_grant         (arch_grant),    // one-hot grant from RR arbiter
    .arch_en            (arch_en),       // arbiter enable (combinational + registered)
    .arch_en_c          (arch_en_c),     // combinational enable component
    .arch_en_r          (arch_en_r),     // registered enable component

    // R channel routing
    .mst_rch_targeted   (mst_rch_targeted)  // per-master ID mask match result
);

`resetall
