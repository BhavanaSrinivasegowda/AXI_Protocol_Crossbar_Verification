// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

`timescale 1 ns / 1 ps

module rr_tb_top;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import rr_pkg::*;

    logic aclk;
    logic aresetn;

    initial aclk = 1'b0;
    always #5 aclk = ~aclk;

    initial begin
        aresetn = 1'b0;
        repeat (5) @(posedge aclk);
        aresetn = 1'b1;
    end

    rr_if #(.REQ_NB(RR_REQ_NB)) vif (.aclk(aclk), .aresetn(aresetn));

    axicb_round_robin_core #(
        .REQ_NB (RR_REQ_NB)
    ) u_dut (
        .aclk    (aclk),
        .aresetn (aresetn),
        .srst    (vif.srst),
        .en      (vif.en),
        .req     (vif.req),
        .grant   (vif.grant)
    );

    initial begin
        uvm_config_db#(virtual rr_if#(RR_REQ_NB))::set(null, "*", "vif", vif);
        run_test();
    end

endmodule
