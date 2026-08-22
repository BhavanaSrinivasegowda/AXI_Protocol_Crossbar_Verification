// =============================================================================
// FILE         : slv_ooo_bind.sv
// PROJECT      : AXI Crossbar FPV
// DESCRIPTION  : Bind file attaching slv_ooo_props to axicb_slv_ooo.
//                Exposes push, pull, id_full, id_empty, fifo_out, c_select,
//                c_reqs, id_grant, mr_reqs, c_empty and a_id_m — all declared
//                directly in axicb_slv_ooo (outside the OSTDREQ_NUM==1
//                generate branch that bypasses them) — for white-box
//                per-ID FIFO and completion-arbitration properties.
//                No DUT source modification required.
// TOOL         : JasperGold Formal Property Verification
// =============================================================================

`timescale 1 ns / 1 ps
`default_nettype none

bind axicb_slv_ooo slv_ooo_props #(
    .RD_PATH         (RD_PATH),
    .AXI_ID_W        (AXI_ID_W),
    .SLV_NB          (SLV_NB),
    .MST_OSTDREQ_NUM (MST_OSTDREQ_NUM),
    .MST_ID_MASK     (MST_ID_MASK),
    .CCH_W           (CCH_W)
) u_slv_ooo_props (

    // -------------------------------------------------------------------------
    // Primary interface — mirrors axicb_slv_ooo port list exactly
    // -------------------------------------------------------------------------
    .aclk     (aclk),
    .aresetn  (aresetn),
    .srst     (srst),

    .a_valid  (a_valid),
    .a_ready  (a_ready),
    .a_full   (a_full),
    .a_len    (a_len),
    .a_id     (a_id),
    .a_ix     (a_ix),
    .a_mr     (a_mr),

    .c_en     (c_en),
    .c_grant  (c_grant),
    .c_mr     (c_mr),
    .c_len    (c_len),
    .c_id     (c_id),

    .c_valid  (c_valid),
    .c_ready  (c_ready),
    .c_ch     (c_ch),
    .c_end    (c_end),

    // -------------------------------------------------------------------------
    // Internal signals from axicb_slv_ooo — accessible via bind scope
    // Used for white-box assertions on ID-FIFO and arbitration correctness
    // -------------------------------------------------------------------------
    .push      (push),
    .pull      (pull),
    .id_full   (id_full),
    .id_empty  (id_empty),
    .fifo_out  (fifo_out),
    .c_select  (c_select),
    .c_reqs    (c_reqs),
    .id_grant  (id_grant),
    .mr_reqs   (mr_reqs),
    .a_id_m    (a_id_m),
    .c_empty   (c_empty)
);

`resetall
