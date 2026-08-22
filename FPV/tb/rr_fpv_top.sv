// =============================================================================
// FILE         : rr_fpv_top.sv
// PROJECT      : AXI Crossbar FPV
// DESCRIPTION  : Formal testbench top for axicb_round_robin.
//                Instantiates the DUT with unconstrained primary inputs.
//                Constraints (assumptions) are defined entirely in rr_props.sv
//                and attached via rr_bind.sv — nothing is constrained here.
//
//                Parameter choices:
//                  REQ_NB=4           matches the crossbar's actual MST_NB
//                  NUM_PRIORITY_LVL=4 exercises full priority hierarchy
//                  PRIORITY           assigns distinct levels to each requester
//                  so priority-preemption properties are non-vacuous
//
// TOOL         : JasperGold Formal Property Verification
// =============================================================================

`timescale 1 ns / 1 ps
`default_nettype wire


module rr_fpv_top;

    // =========================================================================
    // Parameters — kept as localparams so TCL elaborate can override via
    // -parameter on the DUT instance, not the TB wrapper
    // =========================================================================
    localparam int unsigned REQ_NB           = 4;
    localparam int unsigned PRIORITY_W       = 2;
    localparam int unsigned NUM_PRIORITY_LVL = 4;

    // Priority assignment: req0=P0, req1=P1, req2=P2, req3=P3
    // Each requester at a distinct level — exercises preemption in both
    // directions and ensures all p_active combinations are reachable
    localparam [(PRIORITY_W*REQ_NB)-1:0] PRIORITY = {
        2'd3,   // req3 → priority level 3 (highest)
        2'd2,   // req2 → priority level 2
        2'd1,   // req1 → priority level 1
        2'd0    // req0 → priority level 0 (lowest)
    };

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
    // Assumptions in rr_props.sv restrict them to valid operating conditions
    // =========================================================================
    logic [REQ_NB-1:0] req;
    logic              en;

    // =========================================================================
    // DUT outputs — observed by properties
    // =========================================================================
    logic [REQ_NB-1:0] grant;

    // =========================================================================
    // DUT instantiation
    // =========================================================================
    axicb_round_robin #(
        .REQ_NB           (REQ_NB),
        .PRIORITY_W       (PRIORITY_W),
        .NUM_PRIORITY_LVL (NUM_PRIORITY_LVL),
        .PRIORITY         (PRIORITY)
    ) u_dut (
        .aclk    (aclk),
        .aresetn (aresetn),
        .srst    (srst),
        .en      (en),
        .req     (req),
        .grant   (grant)
    );

    // =========================================================================
    // Formal clock declaration
    // Actual clock constraints are set in rr_fpv.tcl via the 'clock' command.
    // The initial block below is for simulation compatibility only and is
    // ignored by the formal tool.
    // =========================================================================
    `ifdef SIMULATION
        initial aclk = 1'b0;
        always  #5 aclk = ~aclk;
    `endif

endmodule

`resetall
