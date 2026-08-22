// =============================================================================
// FILE         : slv_ooo_fpv_top.sv
// PROJECT      : AXI Crossbar FPV
// DESCRIPTION  : Formal testbench top for axicb_slv_ooo, verified as a
//                standalone unit. Instantiates the DUT with unconstrained
//                primary inputs — a_valid/a_ready/a_len/a_id/a_ix/a_mr,
//                c_en/c_valid/c_ready/c_ch/c_end all carry no crossbar-level
//                constraints. Assumptions (kept to environment legality only)
//                and all properties live in slv_ooo_props.sv, attached via
//                slv_ooo_bind.sv — nothing is constrained here.
//
//                Dependency chain:
//                  axicb_slv_ooo
//                    └─ axicb_scfifo             (BLOCK="REGFILE", per-ID
//                                                  FIFO, MST_OSTDREQ_NUM
//                                                  instances)
//                    └─ axicb_round_robin_core    (completion arbitration
//                                                   across outstanding IDs)
//                    └─ axicb_pipeline            (OSTDREQ_NUM==1 bypass
//                                                   path — unused this pass)
//
//                FIRST PASS SCOPE:
//                  RD_PATH=0          (write/B completion path — no ALEN)
//                  MST_OSTDREQ_NUM=4  (> 1, real per-ID FIFO + round-robin
//                                      arbitration path elaborated)
//                  RD_PATH=1 and MST_OSTDREQ_NUM=1 are future work — see the
//                  scope notes at the top of slv_ooo_props.sv for what
//                  changes under each.
//
//                Parameter choices:
//                  AXI_ID_W=8    wide enough that asm_aid_in_range in
//                                slv_ooo_props.sv is a genuine constraint,
//                                not a tautology (NB_ID=4 << 2**AXI_ID_W)
//                  SLV_NB=4      matches the crossbar's default slave count
//                                used throughout the other FPV suites
//                  CCH_W=10      matches BCH_W's default in
//                                axicb_slv_switch_wr.sv (ID + resp bits)
//
// TOOL         : JasperGold Formal Property Verification
// =============================================================================

`timescale 1 ns / 1 ps
`default_nettype wire

module slv_ooo_fpv_top;

    // =========================================================================
    // Parameters — kept as localparams so TCL elaborate can override via
    // -parameter on the DUT instance, not the TB wrapper
    // =========================================================================
    localparam int unsigned    RD_PATH         = 0;
    localparam int unsigned    AXI_ID_W        = 8;
    localparam int unsigned    SLV_NB          = 4;
    localparam int unsigned    MST_OSTDREQ_NUM = 4;
    localparam [AXI_ID_W-1:0]  MST_ID_MASK     = 'h00;
    localparam int unsigned    CCH_W           = 10;

    // =========================================================================
    // Clock and reset — declared as free-running logic
    // Formal tool takes control of reset sequencing
    // Clock period and phase are specified in the TCL (clock command)
    // =========================================================================
    logic aclk;
    logic aresetn;
    logic srst;

    // =========================================================================
    // DUT primary inputs — left unconstrained here
    // Assumptions in slv_ooo_props.sv restrict only environment legality
    // (X/Z, valid/ready stability, one-hot routing, ID budget)
    // =========================================================================
    logic                     a_valid;
    logic                     a_ready;
    logic [8            -1:0] a_len;
    logic [AXI_ID_W     -1:0] a_id;
    logic [SLV_NB       -1:0] a_ix;
    logic                     a_mr;

    logic                     c_en;
    logic [SLV_NB       -1:0] c_valid;
    logic                     c_ready;
    logic [CCH_W*SLV_NB -1:0] c_ch;
    logic                     c_end;

    // =========================================================================
    // DUT outputs — observed by properties
    // =========================================================================
    logic                     a_full;
    logic [SLV_NB       -1:0] c_grant;
    logic                     c_mr;
    logic [8            -1:0] c_len;
    logic [AXI_ID_W     -1:0] c_id;

    // =========================================================================
    // DUT instantiation
    // =========================================================================
    axicb_slv_ooo #(
        .RD_PATH         (RD_PATH),
        .AXI_ID_W        (AXI_ID_W),
        .SLV_NB          (SLV_NB),
        .MST_OSTDREQ_NUM (MST_OSTDREQ_NUM),
        .MST_ID_MASK     (MST_ID_MASK),
        .CCH_W           (CCH_W)
    ) u_dut (
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
        .c_end    (c_end)
    );

    // =========================================================================
    // Formal clock declaration
    // Actual clock constraints are set in slv_ooo_fpv.tcl via the 'clock' command.
    // The initial block below is for simulation compatibility only and is
    // ignored by the formal tool.
    // =========================================================================
    `ifdef SIMULATION
        initial aclk = 1'b0;
        always  #5 aclk = ~aclk;
    `endif

endmodule

`resetall
