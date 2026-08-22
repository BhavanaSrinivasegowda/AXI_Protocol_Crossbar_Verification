// =============================================================================
// FILE         : mst_switch_wr_bind.sv
// PROJECT      : AXI Crossbar FPV
// DESCRIPTION  : Bind file attaching mst_switch_wr_props to
//                axicb_mst_switch_wr. Exposes both port-level AXI signals
//                and internal signals (grant, FIFO status, B-targeting)
//                needed for white-box AXI protocol and routing properties.
//                No DUT source modification required.
// TOOL         : JasperGold Formal Property Verification
// =============================================================================

`timescale 1 ns / 1 ps
`default_nettype none

bind axicb_mst_switch_wr mst_switch_wr_props #(
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
    .RCH_W            (RCH_W),
    // FIFO_OPEN=0 : Pass 1 — FIFO black-boxed (default).
    //               All generate if (FIFO_OPEN) blocks are inactive:
    //               B22/B25/B37 assertions and C6/C7/C12/C14/C15 covers
    //               do not exist. TCL bbox constraints (wch_empty=1,
    //               wch_full=0, wch_grant=0) are consistent with this.
    // FIFO_OPEN=1 : Pass 2 — full FIFO state space. Change to 1 here
    //               and remove -bbox_m axicb_scfifo from TCL elaborate.
    .FIFO_OPEN        (0)
) u_mst_switch_wr_props (

    // -------------------------------------------------------------------------
    // Global interface
    // -------------------------------------------------------------------------
    .aclk               (aclk),
    .aresetn            (aresetn),
    .srst               (srst),

    // -------------------------------------------------------------------------
    // AXI Write Address Channel — Master side (input to switch)
    // -------------------------------------------------------------------------
    .i_awvalid          (i_awvalid),
    .i_awready          (i_awready),
    .i_awch             (i_awch),

    // -------------------------------------------------------------------------
    // AXI Write Data Channel — Master side
    // -------------------------------------------------------------------------
    .i_wvalid           (i_wvalid),
    .i_wready           (i_wready),
    .i_wlast            (i_wlast),
    .i_wch              (i_wch),

    // -------------------------------------------------------------------------
    // AXI Write Response Channel — Master side
    // -------------------------------------------------------------------------
    .i_bvalid           (i_bvalid),
    .i_bready           (i_bready),
    .i_bch              (i_bch),

    // -------------------------------------------------------------------------
    // AXI Write Address Channel — Slave side (output from switch)
    // -------------------------------------------------------------------------
    .o_awvalid          (o_awvalid),
    .o_awready          (o_awready),
    .o_awch             (o_awch),

    // -------------------------------------------------------------------------
    // AXI Write Data Channel — Slave side
    // -------------------------------------------------------------------------
    .o_wvalid           (o_wvalid),
    .o_wready           (o_wready),
    .o_wlast            (o_wlast),
    .o_wch              (o_wch),

    // -------------------------------------------------------------------------
    // AXI Write Response Channel — Slave side
    // -------------------------------------------------------------------------
    .o_bvalid           (o_bvalid),
    .o_bready           (o_bready),
    .o_bch              (o_bch),

    // -------------------------------------------------------------------------
    // Internal signals — white-box access via bind scope
    // -------------------------------------------------------------------------

    // AW channel arbitration internals
    .awch_en            (awch_en),       // arbiter enable (combinational + registered)
    .awch_en_c          (awch_en_c),     // combinational enable component
    .awch_en_r          (awch_en_r),     // registered enable component
    .awch_grant         (awch_grant),    // one-hot grant from RR arbiter

    // W channel grant tracking (stored in FIFO)
    .wch_grant          (wch_grant),     // FIFO output — which master owns W channel
    .wch_full           (wch_full),      // FIFO full flag — blocks new AW grants
    .wch_empty          (wch_empty),     // FIFO empty flag — W channel has no owner

    // B channel routing
    .mst_bch_targeted   (mst_bch_targeted)  // per-master ID mask match result
);

`resetall