// =============================================================================
// FILE         : mst_switch_rd_props.sv
// PROJECT      : AXI Crossbar FPV
// MODULE       : mst_switch_rd_props (bound to axicb_mst_switch_rd)
// DESCRIPTION  : White-box properties for the master-side read switch.
//                Structurally this is the read counterpart of
//                axicb_mst_switch_wr, but simpler: there is no grant-memory
//                FIFO on the read data path because R responses already
//                carry the ID needed to route them back to the requesting
//                master (mst_rch_targeted), unlike W which carries no ID.
//                Two channels only:
//                  - AR : masters -> switch -> slave, round-robin arbitrated
//                  - R  : slave -> switch -> masters, routed by ID mask
// =============================================================================
`resetall
`timescale 1 ns / 1 ps
`default_nettype wire

module mst_switch_rd_props #(
    parameter int unsigned AXI_ID_W         = 8,
    parameter int unsigned AXI_DATA_W       = 8,
    parameter int unsigned MST_NB           = 4,
    parameter int unsigned NUM_PRIORITY_LVL = 4,
    parameter int unsigned TIMEOUT_ENABLE   = 0,
    parameter [AXI_ID_W*MST_NB-1:0] MST_ID_MASK  = 'h40_30_20_10,
    parameter int unsigned PRIORITY_W       = 2,
    parameter [PRIORITY_W*MST_NB-1:0] MST_PRIORITY = 0,
    parameter int unsigned AWCH_W           = 8,
    parameter int unsigned WCH_W            = 8,
    parameter int unsigned BCH_W            = 8,
    parameter int unsigned ARCH_W           = 8,
    parameter int unsigned RCH_W            = 8
)(
    input logic                         aclk,
    input logic                         aresetn,
    input logic                         srst,
    input logic [MST_NB-1:0]           i_arvalid,
    input logic [MST_NB-1:0]           i_arready,
    input logic [MST_NB*ARCH_W-1:0]    i_arch,
    input logic [MST_NB-1:0]           i_rvalid,
    input logic [MST_NB-1:0]           i_rready,
    input logic [MST_NB-1:0]           i_rlast,
    input logic [RCH_W-1:0]            i_rch,
    input logic                         o_arvalid,
    input logic                         o_arready,
    input logic [ARCH_W-1:0]           o_arch,
    input logic                         o_rvalid,
    input logic                         o_rready,
    input logic                         o_rlast,
    input logic [RCH_W-1:0]            o_rch,
    input logic [MST_NB-1:0]           arch_grant,
    input logic                         arch_en,
    input logic                         arch_en_c,
    input logic                         arch_en_r,
    input logic [MST_NB-1:0]           mst_rch_targeted
);

    wire ar_handshake      = o_arvalid & o_arready;
    wire r_last_handshake  = o_rvalid & o_rready & o_rlast;

    wire [MST_NB-1:0] mst_ar_handshake;
    generate
        for (genvar i = 0; i < MST_NB; i++) begin : GEN_MST_AR_HS
            assign mst_ar_handshake[i] = i_arvalid[i] & i_arready[i];
        end
    endgenerate

    wire [MST_NB-1:0] mst_r_handshake;
    generate
        for (genvar i = 0; i < MST_NB; i++) begin : GEN_MST_R_HS
            assign mst_r_handshake[i] = i_rvalid[i] & i_rready[i];
        end
    endgenerate

    wire [AXI_ID_W-1:0] o_rid = o_rch[AXI_ID_W-1:0];

    logic [AXI_ID_W-1:0] mst_id_mask [MST_NB-1:0];
    generate
        for (genvar i = 0; i < MST_NB; i++) begin : GEN_MST_ID_MASK
            assign mst_id_mask[i] = MST_ID_MASK[i*AXI_ID_W +: AXI_ID_W];
        end
    endgenerate

    default clocking cb @(posedge aclk);
    endclocking

    default disable iff (!aresetn);

    // =========================================================================
    // SECTION A — ASSUMPTIONS
    // =========================================================================

    // A1
    generate
        for (genvar i = 0; i < MST_NB; i++) begin : GEN_ASM_ARVALID_STABLE
            asm_arvalid_stable_i: assume property (
                @(posedge aclk) disable iff (!aresetn)
                (i_arvalid[i] && !i_arready[i]) |=> i_arvalid[i]
            );
        end
    endgenerate

    // A2
    generate
        for (genvar i = 0; i < MST_NB; i++) begin : GEN_ASM_ARCH_STABLE
            asm_arch_stable_i: assume property (
                @(posedge aclk) disable iff (!aresetn)
                (i_arvalid[i] && !i_arready[i]) |=> (i_arch[i*ARCH_W +: ARCH_W] == $past(i_arch[i*ARCH_W +: ARCH_W]))
            );
        end
    endgenerate

    // A3
    asm_rready_not_x: assume property (
        @(posedge aclk) disable iff (!aresetn)
        !$isunknown(i_rready)
    );

    // A4
    asm_arvalid_not_x: assume property (
        @(posedge aclk) disable iff (!aresetn)
        !$isunknown(i_arvalid)
    );

    // A5
    asm_arready_not_x: assume property (
        @(posedge aclk) disable iff (!aresetn)
        !$isunknown(o_arready)
    );

    // A6
    asm_rvalid_stable: assume property (
        @(posedge aclk) disable iff (!aresetn)
        (o_rvalid && !o_rready) |=> o_rvalid
    );

    // A7
    asm_rch_stable: assume property (
        @(posedge aclk) disable iff (!aresetn)
        (o_rvalid && !o_rready) |=> (o_rch == $past(o_rch))
    );

    // A8
    asm_rlast_stable: assume property (
        @(posedge aclk) disable iff (!aresetn)
        (o_rvalid && !o_rready) |=> (o_rlast == $past(o_rlast))
    );

    // A9
    asm_rch_id_in_range: assume property (
        @(posedge aclk) disable iff (!aresetn)
        o_rvalid |-> $onehot(mst_rch_targeted)
    );

    // A10
    asm_reset_at_start: assume property (
        @(posedge aclk)
        $rose(aresetn) |-> aresetn
    );

    // A11
    asm_srst_not_with_areset: assume property (
        @(posedge aclk)
        !aresetn |-> !srst
    );

    // A12
    asm_srst_rare: assume property (
        @(posedge aclk) disable iff (!aresetn)
        srst |-> (srst [*1:2])
    );

    // =========================================================================
    // SECTION B — ASSERTIONS
    // =========================================================================

    // B1 [REMOVED] — srst only clears the round-robin's fairness state
    // (mask/grant_r), not the pending requests themselves. If a master's
    // ARVALID is still asserted when srst fires, axicb_round_robin_core's
    // masked==0 combinational re-arbitration path grants it again the very
    // next cycle, so o_arvalid is not guaranteed to clear after srst. This
    // was never actually a valid invariant (confirmed CEX at bound 2).

    // B2
    ast_grant_onehot_or_zero: assert property (
        @(posedge aclk) disable iff (!aresetn)
        $onehot0(arch_grant)
    );

    // B3
    ast_arvalid_out_implies_grant: assert property (
        @(posedge aclk) disable iff (!aresetn)
        o_arvalid |-> |arch_grant
    );

    // B4
    generate
        for (genvar i = 0; i < MST_NB; i++) begin : GEN_AST_ARVALID_CORRECT
            ast_arvalid_out_correct_master_i: assert property (
                @(posedge aclk) disable iff (!aresetn)
                arch_grant[i] |-> (o_arvalid == i_arvalid[i])
            );
        end
    endgenerate

    // B5
    generate
        for (genvar i = 0; i < MST_NB; i++) begin : GEN_AST_ARCH_CORRECT
            ast_arch_out_correct_payload_i: assert property (
                @(posedge aclk) disable iff (!aresetn)
                (arch_grant[i] && o_arvalid) |-> (o_arch == i_arch[i*ARCH_W +: ARCH_W])
            );
        end
    endgenerate

    // B6
    generate
        for (genvar i = 0; i < MST_NB; i++) begin : GEN_AST_ARREADY_ONLY_GRANTED
            ast_arready_only_to_granted_i: assert property (
                @(posedge aclk) disable iff (!aresetn)
                i_arready[i] |-> arch_grant[i]
            );
        end
    endgenerate

    // B7
    ast_no_arvalid_out_without_master_req: assert property (
        @(posedge aclk) disable iff (!aresetn)
        (i_arvalid == '0) |-> (o_arvalid == 1'b0)
    );

    // B8 [disable iff also covers srst: a mid-transaction soft reset
    //     force-clears grant_r in axicb_round_robin_core, which would
    //     otherwise falsely violate this stability check — confirmed CEX
    //     at bound 3 without the srst guard]
    ast_arvalid_stable_until_arready: assert property (
        @(posedge aclk) disable iff (!aresetn || srst)
        (o_arvalid && !o_arready) |=> o_arvalid
    );

    // B9 [disable iff also covers srst — see B8: srst force-clears
    //     arch_en_r via its own explicit branch, independent of
    //     arch_grant, which would otherwise falsely violate this check
    //     (confirmed CEX at bound 2 without the srst guard)]
    ast_en_r_set_when_no_grant: assert property (
        @(posedge aclk) disable iff (!aresetn || srst)
        (arch_grant == '0) |=> arch_en_r
    );

    // B10
    ast_en_r_clear_when_grant: assert property (
        @(posedge aclk) disable iff (!aresetn)
        |arch_grant |=> !arch_en_r
    );

    // B11
    ast_arch_en_c_correct: assert property (
        @(posedge aclk) disable iff (!aresetn)
        arch_en_c == (|i_arvalid & o_arready)
    );

    // B12
    ast_arch_en_correct: assert property (
        @(posedge aclk) disable iff (!aresetn)
        arch_en == (arch_en_c | arch_en_r)
    );

    // B13
    ast_rvalid_onehot_or_zero: assert property (
        @(posedge aclk) disable iff (!aresetn)
        $onehot0(i_rvalid)
    );

    // B14
    generate
        for (genvar i = 0; i < MST_NB; i++) begin : GEN_AST_RVALID_REQUIRES_ORVALID
            ast_rvalid_only_when_o_rvalid_i: assert property (
                @(posedge aclk) disable iff (!aresetn)
                i_rvalid[i] |-> o_rvalid
            );
        end
    endgenerate

    // B15
    generate
        for (genvar i = 0; i < MST_NB; i++) begin : GEN_AST_RVALID_CORRECT_MASTER
            ast_rvalid_correct_master_by_mask_i: assert property (
                @(posedge aclk) disable iff (!aresetn)
                i_rvalid[i] |-> ((mst_id_mask[i] & o_rid) == mst_id_mask[i])
            );
        end
    endgenerate

    // B16
    generate
        for (genvar i = 0; i < MST_NB; i++) begin : GEN_AST_RVALID_NOT_WRONG
            ast_rvalid_not_driven_wrong_master_i: assert property (
                @(posedge aclk) disable iff (!aresetn)
                (o_rvalid && ((mst_id_mask[i] & o_rid) != mst_id_mask[i])) |-> !i_rvalid[i]
            );
        end
    endgenerate

    // B17
    generate
        for (genvar i = 0; i < MST_NB; i++) begin : GEN_AST_RREADY_FOLLOWS
            ast_rready_follows_targeted_master_i: assert property (
                @(posedge aclk) disable iff (!aresetn)
                (mst_rch_targeted[i] && o_rvalid) |-> (o_rready == i_rready[i])
            );
        end
    endgenerate

    // B18
    ast_rch_passthrough: assert property (
        @(posedge aclk) disable iff (!aresetn)
        i_rch == o_rch
    );

    // B19
    ast_no_rvalid_when_no_id_match: assert property (
        @(posedge aclk) disable iff (!aresetn)
        (mst_rch_targeted == '0) |-> ((i_rvalid == '0) && (o_rready == 1'b0))
    );

    // B20
    generate
        for (genvar i = 0; i < MST_NB; i++) begin : GEN_AST_RLAST_PASSTHROUGH
            // Qualified with o_rvalid to match the RTL's i_rlast gating
            // (axicb_mst_switch_rd.sv now ANDs o_rvalid into i_rlast, same
            // as i_rvalid, so the RTL is free to force i_rlast low here
            // when o_rvalid=0 regardless of o_rlast's don't-care value).
            ast_rlast_passthrough_targeted_i: assert property (
                @(posedge aclk) disable iff (!aresetn)
                (mst_rch_targeted[i] && o_rvalid) |-> (i_rlast[i] == o_rlast)
            );
        end
    endgenerate

    // B21
    generate
        for (genvar i = 0; i < MST_NB; i++) begin : GEN_AST_RLAST_ZERO_NOT_TARGETED
            ast_rlast_zero_when_not_targeted_i: assert property (
                @(posedge aclk) disable iff (!aresetn)
                !mst_rch_targeted[i] |-> !i_rlast[i]
            );
        end
    endgenerate

    // B22
    generate
        for (genvar i = 0; i < MST_NB; i++) begin : GEN_AST_RLAST_REQUIRES_RVALID
            ast_rlast_requires_rvalid_i: assert property (
                @(posedge aclk) disable iff (!aresetn)
                i_rlast[i] |-> i_rvalid[i]
            );
        end
    endgenerate

    // B23
    ast_all_masters_idle_no_output: assert property (
        @(posedge aclk) disable iff (!aresetn)
        (i_arvalid == '0) |-> (o_arvalid == 1'b0)
    );

    // B24
    ast_srst_clears_en_r: assert property (
        @(posedge aclk) disable iff (!aresetn)
        srst |=> (arch_en_r == 1'b0)
    );

    // =========================================================================
    // SECTION C — COVER PROPERTIES
    // =========================================================================

    // C1-C4
    generate
        for (genvar i = 0; i < MST_NB; i++) begin : GEN_COV_AR_HS
            cov_ar_handshake_per_master_i: cover property (
                @(posedge aclk) disable iff (!aresetn)
                (i_arvalid[i] && i_arready[i])
            );
        end
    endgenerate

    // C5
    cov_back_to_back_ar: cover property (
        @(posedge aclk) disable iff (!aresetn)
        ar_handshake ##1 ar_handshake
    );

    // C6
    cov_concurrent_ar_requests: cover property (
        @(posedge aclk) disable iff (!aresetn)
        (i_arvalid == {MST_NB{1'b1}})
    );

    // C7
    cov_r_handshake: cover property (
        @(posedge aclk) disable iff (!aresetn)
        (o_rvalid && o_rready)
    );

    // C8
    cov_rlast_fires: cover property (
        @(posedge aclk) disable iff (!aresetn)
        (o_rvalid && o_rready && o_rlast)
    );

    // C9-C12
    generate
        for (genvar i = 0; i < MST_NB; i++) begin : GEN_COV_R_ROUTED
            cov_r_response_routed_per_master_i: cover property (
                @(posedge aclk) disable iff (!aresetn)
                (i_rvalid[i] && o_rvalid)
            );
        end
    endgenerate

    // C13
    cov_ar_then_r_complete: cover property (
        @(posedge aclk) disable iff (!aresetn)
        ar_handshake
        ##[1:16] r_last_handshake
    );

endmodule

`resetall
