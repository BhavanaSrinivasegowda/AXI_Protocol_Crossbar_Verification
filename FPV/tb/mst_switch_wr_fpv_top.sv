// =============================================================================
// FILE         : mst_switch_wr_fpv_top.sv
// PROJECT      : AXI Crossbar FPV
// DESCRIPTION  : Formal testbench top for axicb_mst_switch_wr.
//                Instantiates the DUT and all RTL dependencies with
//                unconstrained primary inputs. AXI protocol assumptions
//                are defined in mst_switch_wr_props.sv and attached via
//                mst_switch_wr_bind.sv.
//
//                Dependency chain:
//                  axicb_mst_switch_wr
//                    └─ axicb_round_robin
//                         └─ axicb_round_robin_core
//                    └─ axicb_scfifo        (wch_gnt_fifo)
//                         └─ axicb_scfifo_ram  OR  axicb_scfifo_regfile
//
//                FIFO strategy:
//                  First pass — FIFO is black-boxed in TCL to reduce state
//                  space and let AW/W/B channel properties converge quickly.
//                  Second pass — black box removed, full FIFO state included.
//                  See mst_switch_wr_fpv.tcl for the bbox toggle comment.
//
//                Parameter choices:
//                  MST_NB=4  matches the crossbar configuration
//                  AWCH_W/WCH_W/BCH_W kept minimal (8-bit) for convergence
//                  AXI_ID_W=8 with distinct ID masks per master
//
// TOOL         : JasperGold Formal Property Verification
// =============================================================================

`timescale 1 ns / 1 ps
`default_nettype wire

module mst_switch_wr_fpv_top;

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
    parameter int unsigned FIFO_OPEN = 0;

    // ID masks — match axicb_crossbar_top.json configuration
    // Each master has a unique upper nibble so the B-channel routing
    // properties can distinguish which master a BRESP belongs to
    // FIX: masks MUST be bit-disjoint (non-overlapping) because the RTL
    // B-routing uses SUBSET-match semantics: (mask[i] & bid) == mask[i].
    // The previous values 0x40/0x30/0x20/0x10 overlapped:
    //   0x20 & 0x30 = 0x20 != 0,  0x10 & 0x30 = 0x10 != 0
    // That made asm_id_masks_nonoverlapping a constant-FALSE assumption and
    // also made $onehot(mst_bch_targeted) impossible for bid=0x30 (three
    // masks match), producing WAS006/EAS003 "inconsistent at cycle 1".
    // One-hot disjoint masks guarantee exactly one mask matches each legal BID.
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
    logic [MST_NB-1:0]           i_awvalid;
    logic [MST_NB*AWCH_W-1:0]    i_awch;

    logic [MST_NB-1:0]           i_wvalid;
    logic [MST_NB-1:0]           i_wlast;
    logic [MST_NB*WCH_W-1:0]     i_wch;

    logic [MST_NB-1:0]           i_bready;

    // Slave → Switch (output side, driven by slave model)
    logic                         o_awready;
    logic                         o_wready;
    logic                         o_bvalid;
    logic [BCH_W-1:0]             o_bch;

    // =========================================================================
    // DUT outputs — observed by properties
    // =========================================================================
    logic [MST_NB-1:0]           i_awready;
    logic [MST_NB-1:0]           i_wready;
    logic [MST_NB-1:0]           i_bvalid;
    logic [BCH_W-1:0]            i_bch;

    logic                         o_awvalid;
    logic [AWCH_W-1:0]           o_awch;
    logic                         o_wvalid;
    logic                         o_wlast;
    logic [WCH_W-1:0]            o_wch;
    logic                         o_bready;

    // =========================================================================
    // DUT instantiation
    // =========================================================================
    axicb_mst_switch_wr #(
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
        .i_awvalid  (i_awvalid),
        .i_awready  (i_awready),
        .i_awch     (i_awch),
        .i_wvalid   (i_wvalid),
        .i_wready   (i_wready),
        .i_wlast    (i_wlast),
        .i_wch      (i_wch),
        .i_bvalid   (i_bvalid),
        .i_bready   (i_bready),
        .i_bch      (i_bch),
        .o_awvalid  (o_awvalid),
        .o_awready  (o_awready),
        .o_awch     (o_awch),
        .o_wvalid   (o_wvalid),
        .o_wready   (o_wready),
        .o_wlast    (o_wlast),
        .o_wch      (o_wch),
        .o_bvalid   (o_bvalid),
        .o_bready   (o_bready),
        .o_bch      (o_bch)
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