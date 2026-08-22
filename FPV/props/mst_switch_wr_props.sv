// =============================================================================
// FILE         : mst_switch_wr_props.sv
// PROJECT      : AXI Crossbar FPV
// MODULE       : mst_switch_wr_props (bound to axicb_mst_switch_wr)
// =============================================================================
`resetall
`timescale 1 ns / 1 ps
`default_nettype wire

module mst_switch_wr_props #(
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
    parameter int unsigned RCH_W            = 8,
    parameter int unsigned FIFO_OPEN        = 0
)(
    input logic                         aclk,
    input logic                         aresetn,
    input logic                         srst,
    input logic [MST_NB-1:0]           i_awvalid,
    input logic [MST_NB-1:0]           i_awready,
    input logic [MST_NB*AWCH_W-1:0]    i_awch,
    input logic [MST_NB-1:0]           i_wvalid,
    input logic [MST_NB-1:0]           i_wready,
    input logic [MST_NB-1:0]           i_wlast,
    input logic [MST_NB*WCH_W-1:0]    i_wch,
    input logic [MST_NB-1:0]           i_bvalid,
    input logic [MST_NB-1:0]           i_bready,
    input logic [BCH_W-1:0]            i_bch,
    input logic                         o_awvalid,
    input logic                         o_awready,
    input logic [AWCH_W-1:0]           o_awch,
    input logic                         o_wvalid,
    input logic                         o_wready,
    input logic                         o_wlast,
    input logic [WCH_W-1:0]            o_wch,
    input logic                         o_bvalid,
    input logic                         o_bready,
    input logic [BCH_W-1:0]            o_bch,
    input logic [MST_NB-1:0]           awch_grant,
    input logic                         awch_en,
    input logic                         awch_en_c,
    input logic                         awch_en_r,
    input logic [MST_NB-1:0]           wch_grant,
    input logic                         wch_full,
    input logic                         wch_empty,
    input logic [MST_NB-1:0]           mst_bch_targeted
);

    wire aw_handshake = o_awvalid & o_awready;
    wire w_last_handshake = o_wvalid & o_wready & o_wlast;
    wire b_handshake = o_bvalid & o_bready;

    wire [MST_NB-1:0] mst_aw_handshake;
    generate
        for (genvar i = 0; i < MST_NB; i++) begin : GEN_MST_AW_HS
            assign mst_aw_handshake[i] = i_awvalid[i] & i_awready[i];
        end
    endgenerate

    wire [MST_NB-1:0] mst_w_handshake;
    generate
        for (genvar i = 0; i < MST_NB; i++) begin : GEN_MST_W_HS
            assign mst_w_handshake[i] = i_wvalid[i] & i_wready[i];
        end
    endgenerate

    wire [MST_NB-1:0] mst_b_handshake;
    generate
        for (genvar i = 0; i < MST_NB; i++) begin : GEN_MST_B_HS
            assign mst_b_handshake[i] = i_bvalid[i] & i_bready[i];
        end
    endgenerate

    wire [AXI_ID_W-1:0] o_bid = o_bch[AXI_ID_W-1:0];

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
        for (genvar i = 0; i < MST_NB; i++) begin : GEN_ASM_AWVALID_STABLE
            asm_awvalid_stable_i: assume property (
                @(posedge aclk) disable iff (!aresetn)
                (i_awvalid[i] && !i_awready[i]) |=> i_awvalid[i]
            );
        end
    endgenerate

    // A2
    generate
        for (genvar i = 0; i < MST_NB; i++) begin : GEN_ASM_WVALID_STABLE
            asm_wvalid_stable_i: assume property (
                @(posedge aclk) disable iff (!aresetn)
                (i_wvalid[i] && !i_wready[i]) |=> i_wvalid[i]
            );
        end
    endgenerate

    // A3
    generate
        for (genvar i = 0; i < MST_NB; i++) begin : GEN_ASM_WLAST_STABLE
            asm_wlast_stable_i: assume property (
                @(posedge aclk) disable iff (!aresetn)
                (i_wvalid[i] && !i_wready[i]) |=> (i_wlast[i] == $past(i_wlast[i]))
            );
        end
    endgenerate

    // A4
    generate
        for (genvar i = 0; i < MST_NB; i++) begin : GEN_ASM_AWCH_STABLE
            asm_awch_stable_i: assume property (
                @(posedge aclk) disable iff (!aresetn)
                (i_awvalid[i] && !i_awready[i]) |=> (i_awch[i*AWCH_W +: AWCH_W] == $past(i_awch[i*AWCH_W +: AWCH_W]))
            );
        end
    endgenerate

    // A5
    generate
        for (genvar i = 0; i < MST_NB; i++) begin : GEN_ASM_WCH_STABLE
            asm_wch_stable_i: assume property (
                @(posedge aclk) disable iff (!aresetn)
                (i_wvalid[i] && !i_wready[i]) |=> (i_wch[i*WCH_W +: WCH_W] == $past(i_wch[i*WCH_W +: WCH_W]))
            );
        end
    endgenerate

    // A6
    asm_bready_not_x: assume property (
        @(posedge aclk) disable iff (!aresetn)
        !$isunknown(i_bready)
    );

    // A7
    asm_awvalid_not_x: assume property (
        @(posedge aclk) disable iff (!aresetn)
        !$isunknown(i_awvalid)
    );

    // A8
    asm_wvalid_not_x: assume property (
        @(posedge aclk) disable iff (!aresetn)
        !$isunknown(i_wvalid)
    );

    // A9
    asm_awready_not_x: assume property (
        @(posedge aclk) disable iff (!aresetn)
        !$isunknown(o_awready)
    );

    // A10
    asm_wready_not_x: assume property (
        @(posedge aclk) disable iff (!aresetn)
        !$isunknown(o_wready)
    );

    // A11
    asm_bvalid_stable: assume property (
        @(posedge aclk) disable iff (!aresetn)
        (o_bvalid && !o_bready) |=> o_bvalid
    );

    // A12
    asm_bch_stable: assume property (
        @(posedge aclk) disable iff (!aresetn)
        (o_bvalid && !o_bready) |=> (o_bch == $past(o_bch))
    );

    // A13
    asm_bch_id_in_range: assume property (
        @(posedge aclk) disable iff (!aresetn)
        o_bvalid |-> $onehot(mst_bch_targeted)
    );

    // A14
    asm_reset_at_start: assume property (
        @(posedge aclk)
        $rose(aresetn) |-> aresetn
    );

    // A15 [PASS2 ONLY — precondition needs !aresetn with srst interaction;
    //      srst=0 in Pass 1 makes this vacuously true with unreachable precondition]
    generate if (FIFO_OPEN) begin : GEN_A15
        asm_srst_not_with_areset: assume property (
            @(posedge aclk)
            !aresetn |-> !srst
        );
    end endgenerate

    // A17
    generate
        for (genvar i = 0; i < MST_NB; i++) begin : GEN_ASM_WLAST_REQ_WVALID
            asm_wlast_requires_wvalid_i: assume property (
                @(posedge aclk) disable iff (!aresetn)
                i_wlast[i] |-> i_wvalid[i]
            );
        end
    endgenerate

    // A18
    generate if (!FIFO_OPEN) begin : GEN_A18_PASS1
        asm_srst_inactive: assume property (
            @(posedge aclk) !srst
        );
    end else begin : GEN_A18_PASS2
        asm_srst_rare: assume property (
            @(posedge aclk) disable iff (!aresetn)
            srst |-> (srst [*1:2])
        );
    end endgenerate

    // =========================================================================
    // SECTION B — ASSERTIONS
    // =========================================================================

    // B2 [PASS2 ONLY — antecedent needs srst=1, forced to 0 in Pass 1 by A18]
    generate if (FIFO_OPEN) begin : GEN_B2
        ast_awvalid_out_clears_after_srst: assert property (
            @(posedge aclk) disable iff (!aresetn)
            srst |=> !o_awvalid
        );
    end endgenerate

    // B3 [PASS2 ONLY — $fell(aresetn) unreachable in formal: tool starts
    //     aresetn=0 and releases to 1, never re-asserts low]
    generate if (FIFO_OPEN) begin : GEN_B3
        ast_wvalid_out_zero_after_areset: assert property (
            @(posedge aclk)
            $fell(aresetn) |-> (o_wvalid == 1'b0)
        );
    end endgenerate

    // B5
    ast_grant_onehot_or_zero: assert property (
        @(posedge aclk) disable iff (!aresetn)
        $onehot0(awch_grant)
    );

    // B6
    ast_awvalid_out_implies_grant: assert property (
        @(posedge aclk) disable iff (!aresetn)
        o_awvalid |-> |awch_grant
    );

    // B7
    generate
        for (genvar i = 0; i < MST_NB; i++) begin : GEN_AST_AWVALID_CORRECT
            ast_awvalid_out_correct_master_i: assert property (
                @(posedge aclk) disable iff (!aresetn)
                awch_grant[i] |-> (o_awvalid == i_awvalid[i])
            );
        end
    endgenerate

    // B8
    generate
        for (genvar i = 0; i < MST_NB; i++) begin : GEN_AST_AWCH_CORRECT
            ast_awch_out_correct_payload_i: assert property (
                @(posedge aclk) disable iff (!aresetn)
                (awch_grant[i] && o_awvalid) |-> (o_awch == i_awch[i*AWCH_W +: AWCH_W])
            );
        end
    endgenerate

    // B9
    generate
        for (genvar i = 0; i < MST_NB; i++) begin : GEN_AST_AWREADY_ONLY_GRANTED
            ast_awready_only_to_granted_i: assert property (
                @(posedge aclk) disable iff (!aresetn)
                i_awready[i] |-> awch_grant[i]
            );
        end
    endgenerate

    // B10 [PASS2 ONLY — antecedent needs wch_full=1, frozen to 0 by bbox in Pass 1]
    generate if (FIFO_OPEN) begin : GEN_B10
        ast_awready_blocked_when_fifo_full: assert property (
            @(posedge aclk) disable iff (!aresetn)
            wch_full |-> (i_awready == '0)
        );
    end endgenerate

    // B11
    ast_no_awvalid_out_without_master_req: assert property (
        @(posedge aclk) disable iff (!aresetn)
        (i_awvalid == '0) |-> (o_awvalid == 1'b0)
    );

    // B12
    ast_awvalid_stable_until_awready: assert property (
        @(posedge aclk) disable iff (!aresetn)
        (o_awvalid && !o_awready) |=> o_awvalid
    );

    // B13
    ast_en_r_set_when_no_grant: assert property (
        @(posedge aclk) disable iff (!aresetn)
        (awch_grant == '0) |=> awch_en_r
    );

    // B14
    ast_en_r_clear_when_grant: assert property (
        @(posedge aclk) disable iff (!aresetn)
        |awch_grant |=> !awch_en_r
    );

    // B15
    ast_awch_en_c_correct: assert property (
        @(posedge aclk) disable iff (!aresetn)
        awch_en_c == (|i_awvalid & o_awready)
    );

    // B16
    ast_awch_en_correct: assert property (
        @(posedge aclk) disable iff (!aresetn)
        awch_en == (awch_en_c | awch_en_r)
    );

    // B17
    ast_wvalid_out_zero_when_fifo_empty: assert property (
        @(posedge aclk) disable iff (!aresetn)
        wch_empty |-> (o_wvalid == 1'b0)
    );

    // B18 [PASS2 ONLY — antecedent needs o_wvalid=1, always 0 when wch_empty=1 bbox]
    generate if (FIFO_OPEN) begin : GEN_B18
        ast_wvalid_out_implies_fifo_not_empty: assert property (
            @(posedge aclk) disable iff (!aresetn)
            o_wvalid |-> !wch_empty
        );
    end endgenerate

    // B19
    ast_wready_zero_when_fifo_empty: assert property (
        @(posedge aclk) disable iff (!aresetn)
        wch_empty |-> (i_wready == '0)
    );

    // B20 [PASS2 ONLY — antecedent needs !wch_empty, frozen to 1 by bbox in Pass 1]
    generate if (FIFO_OPEN) begin : GEN_B20
        for (genvar i = 0; i < MST_NB; i++) begin : GEN_AST_WCH_CORRECT
            ast_wch_out_correct_master_i: assert property (
                @(posedge aclk) disable iff (!aresetn)
                (wch_grant[i] && !wch_empty && o_wvalid) |-> (o_wch == i_wch[i*WCH_W +: WCH_W])
            );
        end
    end endgenerate

    // B21 [PASS2 ONLY — antecedent needs !wch_empty, frozen to 1 by bbox in Pass 1]
    generate if (FIFO_OPEN) begin : GEN_B21
        for (genvar i = 0; i < MST_NB; i++) begin : GEN_AST_WLAST_CORRECT
            ast_wlast_out_correct_master_i: assert property (
                @(posedge aclk) disable iff (!aresetn)
                (wch_grant[i] && !wch_empty) |-> (o_wlast == i_wlast[i])
            );
        end
    end endgenerate

    // B22 [PASS2 ONLY]
    generate if (FIFO_OPEN) begin : GEN_B22
        ast_fifo_push_on_aw_handshake: assert property (
            @(posedge aclk) disable iff (!aresetn)
            aw_handshake |=> !wch_empty
        );
    end endgenerate

    // B23 [PASS2 ONLY — antecedent needs w_last_handshake && !wch_empty,
    //      wch_empty=1 bbox makes this unreachable in Pass 1]
    generate if (FIFO_OPEN) begin : GEN_B23
        ast_fifo_pull_on_wlast_handshake: assert property (
            @(posedge aclk) disable iff (!aresetn)
            (w_last_handshake && !wch_empty) |=> (wch_empty || (wch_grant != $past(wch_grant)))
        );
    end endgenerate

    // B24
    generate
        for (genvar i = 0; i < MST_NB; i++) begin : GEN_AST_W_FOLLOWS_AW
            ast_w_follows_aw_grant_i: assert property (
                @(posedge aclk) disable iff (!aresetn)
                ((awch_grant[i] && aw_handshake) |=> ((wch_grant[i] || wch_empty) or ##1 (wch_grant[i] || wch_empty)))
            );
        end
    endgenerate

    // B25 [PASS2 ONLY]
    generate if (FIFO_OPEN) begin : GEN_B25
        ast_no_wdata_before_aw_accepted: assert property (
            @(posedge aclk) disable iff (!aresetn)
            !aw_handshake throughout (o_wvalid == 1'b0)[*1:$]
        );
    end endgenerate

    // B26
    ast_wch_grant_onehot_or_zero: assert property (
        @(posedge aclk) disable iff (!aresetn)
        $onehot0(wch_grant)
    );

    // B27
    ast_bvalid_onehot_or_zero: assert property (
        @(posedge aclk) disable iff (!aresetn)
        $onehot0(i_bvalid)
    );

    // B28
    generate
        for (genvar i = 0; i < MST_NB; i++) begin : GEN_AST_BVALID_REQUIRES_OBVALID
            ast_bvalid_only_when_o_bvalid_i: assert property (
                @(posedge aclk) disable iff (!aresetn)
                i_bvalid[i] |-> o_bvalid
            );
        end
    endgenerate

    // B29
    generate
        for (genvar i = 0; i < MST_NB; i++) begin : GEN_AST_BVALID_CORRECT_MASTER
            ast_bvalid_correct_master_by_mask_i: assert property (
                @(posedge aclk) disable iff (!aresetn)
                i_bvalid[i] |-> ((mst_id_mask[i] & o_bid) == mst_id_mask[i])
            );
        end
    endgenerate

    // B30
    generate
        for (genvar i = 0; i < MST_NB; i++) begin : GEN_AST_BVALID_NOT_WRONG
            ast_bvalid_not_driven_wrong_master_i: assert property (
                @(posedge aclk) disable iff (!aresetn)
                (o_bvalid && ((mst_id_mask[i] & o_bid) != mst_id_mask[i])) |-> !i_bvalid[i]
            );
        end
    endgenerate

    // B31
    generate
        for (genvar i = 0; i < MST_NB; i++) begin : GEN_AST_BREADY_FOLLOWS
            ast_bready_follows_targeted_master_i: assert property (
                @(posedge aclk) disable iff (!aresetn)
                (mst_bch_targeted[i] && o_bvalid) |-> (o_bready == i_bready[i])
            );
        end
    endgenerate

    // B32
    ast_bch_passthrough: assert property (
        @(posedge aclk) disable iff (!aresetn)
        i_bch == o_bch
    );

    // B33
    ast_no_bvalid_when_no_id_match: assert property (
        @(posedge aclk) disable iff (!aresetn)
        (mst_bch_targeted == '0) |-> ((i_bvalid == '0) && (o_bready == 1'b0))
    );

    // B34 [PASS2 ONLY — antecedent needs wch_full=1, frozen to 0 by bbox in Pass 1]
    generate if (FIFO_OPEN) begin : GEN_B34
        ast_fifo_not_pushed_when_full: assert property (
            @(posedge aclk) disable iff (!aresetn)
            wch_full |-> !(o_awvalid & o_awready)
        );
    end endgenerate

    // B35
    ast_fifo_not_pulled_when_empty: assert property (
        @(posedge aclk) disable iff (!aresetn)
        wch_empty |-> !(o_wvalid & o_wready & o_wlast)
    );

    // B36 [PASS2 ONLY — antecedent needs wch_full=1, frozen to 0 by bbox in Pass 1]
    generate if (FIFO_OPEN) begin : GEN_B36
        ast_wch_full_blocks_awready: assert property (
            @(posedge aclk) disable iff (!aresetn)
            wch_full |-> (i_awready == '0)
        );
    end endgenerate

    // B37 [PASS2 ONLY]
    generate if (FIFO_OPEN) begin : GEN_B37
        ast_fifo_data_preserved: assert property (
            @(posedge aclk) disable iff (!aresetn)
            (wch_empty && aw_handshake) |=> (wch_grant == $past(awch_grant))
        );
    end endgenerate

    // B38
    ast_all_masters_idle_no_output: assert property (
        @(posedge aclk) disable iff (!aresetn)
        ((i_awvalid == '0) && (i_wvalid == '0)) |-> ((o_awvalid == 1'b0) && (o_wvalid == 1'b0))
    );

    // B39 [PASS2 ONLY]
    generate if (FIFO_OPEN) begin : GEN_B39
        ast_srst_clears_en_r: assert property (
            @(posedge aclk) disable iff (!aresetn)
            srst |=> (awch_en_r == 1'b0)
        );
    end endgenerate

    // =========================================================================
    // SECTION C — COVER PROPERTIES
    // =========================================================================

    // C1-C4
    generate
        for (genvar i = 0; i < MST_NB; i++) begin : GEN_COV_AW_HS
            cov_aw_handshake_per_master_i: cover property (
                @(posedge aclk) disable iff (!aresetn)
                (i_awvalid[i] && i_awready[i])
            );
        end
    endgenerate

    // C5
    cov_back_to_back_aw: cover property (
        @(posedge aclk) disable iff (!aresetn)
        aw_handshake ##1 aw_handshake
    );

    // C13
    cov_concurrent_aw_requests: cover property (
        @(posedge aclk) disable iff (!aresetn)
        (i_awvalid == {MST_NB{1'b1}})
    );

    // C6, C7, C8-C11, C12, C14, C15 — require FIFO to be open (Pass 2 only)
    generate if (FIFO_OPEN) begin : GEN_COV_PASS2

        // C6
        cov_w_handshake: cover property (
            @(posedge aclk) disable iff (!aresetn)
            (o_wvalid && o_wready)
        );

        // C7
        cov_wlast_fires: cover property (
            @(posedge aclk) disable iff (!aresetn)
            (o_wvalid && o_wready && o_wlast)
        );

        // C8-C11
        for (genvar i = 0; i < MST_NB; i++) begin : GEN_COV_B_ROUTED
            cov_b_response_routed_per_master: cover property (
                @(posedge aclk) disable iff (!aresetn)
                (i_bvalid[i] && o_bvalid)
            );
        end

        // C12
        cov_fifo_full: cover property (
            @(posedge aclk) disable iff (!aresetn)
            wch_full
        );

        // C14
        cov_aw_then_b_complete: cover property (
            @(posedge aclk) disable iff (!aresetn)
            aw_handshake
            ##[1:16] w_last_handshake
            ##[1:16] b_handshake
        );

        // C15
        cov_fifo_push_then_pull: cover property (
            @(posedge aclk) disable iff (!aresetn)
            aw_handshake ##[1:8] w_last_handshake
        );

    end endgenerate  // GEN_COV_PASS2

endmodule

`resetall