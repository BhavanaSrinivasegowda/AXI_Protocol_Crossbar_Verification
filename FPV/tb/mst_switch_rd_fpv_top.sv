// =============================================================================
// FILE         : mst_switch_rd_fpv_top.sv
// PROJECT      : AXI Crossbar FPV
// DESCRIPTION  : Formal testbench top for axicb_mst_switch_rd.
//                Instantiates the DUT and its RTL dependency with
//                unconstrained primary inputs. AXI protocol assumptions
//                are defined in mst_switch_rd_props.sv and attached via
//                mst_switch_rd_bind.sv.
//
//                Dependency chain:
//                  axicb_mst_switch_rd
//                    └─ axicb_round_robin
//                         └─ axicb_round_robin_core
//
//                Unlike axicb_mst_switch_wr, there is no grant-memory FIFO
//                on this path: R responses carry the master ID directly
//                (mst_rch_targeted), so a single full-state-space pass is
//                sufficient — no black-box toggle is needed.
//
//                Parameter choices:
//                  MST_NB=4  matches the crossbar configuration
//                  ARCH_W/RCH_W kept minimal (8-bit) for convergence
//                  AXI_ID_W=8 with distinct, bit-disjoint ID masks per master
//
// TOOL         : JasperGold Formal Property Verification
// =============================================================================

`timescale 1 ns / 1 ps
`default_nettype wire

module mst_switch_rd_fpv_top;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam int unsigned AXI_ID_W         = 8;
    localparam int unsigned AXI_DATA_W       = 8;
    localparam int unsigned MST_NB           = 4;
    localparam int unsigned NUM_PRIORITY_LVL = 4;
    localparam int unsigned TIMEOUT_ENABLE   = 0;   // disabled for FPV
    localparam int unsigned PRIORITY_W       = 2;
    localparam int unsigned AWCH_W           = 8;
    localparam int unsigned WCH_W            = 8;
    localparam int unsigned BCH_W            = 8;
    localparam int unsigned ARCH_W           = 8;
    localparam int unsigned RCH_W            = 8;

    // ID masks — match axicb_crossbar_top.json configuration
    // Each master has a unique bit so the R-channel routing properties
    // can distinguish which master an RID belongs to.
    // Masks MUST be bit-disjoint (non-overlapping) because the RTL
    // R-routing uses SUBSET-match semantics: (mask[i] & rid) == mask[i].
    // One-hot disjoint masks guarantee exactly one mask matches each legal RID
    // (see mst_switch_wr_fpv_top.sv for the incident this pattern avoids).
    localparam [(AXI_ID_W*MST_NB)-1:0] MST_ID_MASK = {
        8'h08,  // master 3 mask
        8'h04,  // master 2 mask
        8'h02,  // master 1 mask
        8'h01   // master 0 mask
    };

    // All masters same priority — round-robin fairness is the focus here
    // Priority preemption is already covered in rr_fpv_top
    localparam [(PRIORITY_W*MST_NB)-1:0] MST_PRIORITY = {
        2'd0, 2'd0, 2'd0, 2'd0
    };

    // =========================================================================
    // Clock and reset
    // =========================================================================
    logic aclk;
    logic aresetn;
    logic srst;

    // =========================================================================
    // DUT primary inputs — unconstrained; assumptions in props restrict them
    // =========================================================================

    // Master → Switch (input side)
    logic [MST_NB-1:0]           i_arvalid;
    logic [MST_NB*ARCH_W-1:0]    i_arch;

    logic [MST_NB-1:0]           i_rready;

    // Slave → Switch (output side, driven by slave model)
    logic                         o_arready;
    logic                         o_rvalid;
    logic                         o_rlast;
    logic [RCH_W-1:0]             o_rch;

    // =========================================================================
    // DUT outputs — observed by properties
    // =========================================================================
    logic [MST_NB-1:0]           i_arready;
    logic [MST_NB-1:0]           i_rvalid;
    logic [MST_NB-1:0]           i_rlast;
    logic [RCH_W-1:0]            i_rch;

    logic                         o_arvalid;
    logic [ARCH_W-1:0]           o_arch;
    logic                         o_rready;

    // =========================================================================
    // DUT instantiation
    // =========================================================================
    axicb_mst_switch_rd #(
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
    ) u_dut (
        .aclk       (aclk),
        .aresetn    (aresetn),
        .srst       (srst),
        .i_arvalid  (i_arvalid),
        .i_arready  (i_arready),
        .i_arch     (i_arch),
        .i_rvalid   (i_rvalid),
        .i_rready   (i_rready),
        .i_rlast    (i_rlast),
        .i_rch      (i_rch),
        .o_arvalid  (o_arvalid),
        .o_arready  (o_arready),
        .o_arch     (o_arch),
        .o_rvalid   (o_rvalid),
        .o_rready   (o_rready),
        .o_rlast    (o_rlast),
        .o_rch      (o_rch)
    );

    // =========================================================================
    // Simulation clock only — ignored by formal tool
    // =========================================================================
    `ifdef SIMULATION
        initial aclk = 1'b0;
        always  #5 aclk = ~aclk;
    `endif

    wire combined_reset = (!aresetn) || srst;

endmodule

`resetall
