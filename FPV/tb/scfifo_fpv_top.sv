// =============================================================================
// FILE         : scfifo_fpv_top.sv
// PROJECT      : AXI Crossbar FPV
// DESCRIPTION  : Formal testbench top for axicb_scfifo, verified as a
//                standalone unit. Instantiates the DUT with unconstrained
//                primary inputs — push, pull, data_in, flush and srst carry
//                no crossbar-level constraints. Assumptions (kept minimal)
//                and all properties live in scfifo_props.sv, attached via
//                scfifo_bind.sv — nothing is constrained here.
//
//                Dependency chain:
//                  axicb_scfifo
//                    └─ axicb_scfifo_ram      (BLOCK="RAM")
//                    └─ axicb_scfifo_regfile  (BLOCK="REGFILE", unused here)
//
//                FIRST PASS SCOPE:
//                  BLOCK="RAM", PASS_THRU=0 (STORE_MODE) only.
//                  BLOCK="REGFILE" and PASS_THRU=1 are future work — see the
//                  notes on B6/B7 in scfifo_props.sv for what needs to change.
//
//                Parameter choices:
//                  ADDR_WIDTH=2  (DEPTH=4) small enough for fast convergence
//                                while still exercising multiple wraps
//                  DATA_WIDTH=8  wide enough to make the data-integrity
//                                scoreboard non-trivial
//
// TOOL         : JasperGold Formal Property Verification
// =============================================================================

`timescale 1 ns / 1 ps
`default_nettype wire

module scfifo_fpv_top;

    // =========================================================================
    // Parameters — kept as localparams so TCL elaborate can override via
    // -parameter on the DUT instance, not the TB wrapper
    // =========================================================================
    localparam                      BLOCK      = "RAM";
    localparam                      PASS_THRU  = 0;
    localparam int unsigned         ADDR_WIDTH = 2;
    localparam int unsigned         DATA_WIDTH = 8;

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
    // Assumptions in scfifo_props.sv restrict only X/Z, nothing functional
    // =========================================================================
    logic                    flush;
    logic [DATA_WIDTH-1:0]   data_in;
    logic                    push;
    logic                    pull;

    // =========================================================================
    // DUT outputs — observed by properties
    // =========================================================================
    logic                    full;
    logic [DATA_WIDTH-1:0]   data_out;
    logic                    empty;

    // =========================================================================
    // DUT instantiation
    // =========================================================================
    axicb_scfifo #(
        .BLOCK      (BLOCK),
        .PASS_THRU  (PASS_THRU),
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) u_dut (
        .aclk     (aclk),
        .aresetn  (aresetn),
        .srst     (srst),
        .flush    (flush),
        .data_in  (data_in),
        .push     (push),
        .full     (full),
        .data_out (data_out),
        .pull     (pull),
        .empty    (empty)
    );

    // =========================================================================
    // Formal clock declaration
    // Actual clock constraints are set in scfifo_fpv.tcl via the 'clock' command.
    // The initial block below is for simulation compatibility only and is
    // ignored by the formal tool.
    // =========================================================================
    `ifdef SIMULATION
        initial aclk = 1'b0;
        always  #5 aclk = ~aclk;
    `endif

endmodule

`resetall
