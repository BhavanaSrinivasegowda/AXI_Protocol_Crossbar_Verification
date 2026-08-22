// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

`timescale 1 ns / 1 ps

interface rr_if #(
    parameter int REQ_NB = 4
) (
    input wire aclk,
    input wire aresetn
);

    logic              srst;
    logic              en;
    logic [REQ_NB-1:0] req;
    logic [REQ_NB-1:0] grant;

    clocking drv_cb @(posedge aclk);
        default input #1step output #2;
        output srst, en, req;
    endclocking

    clocking mon_cb @(posedge aclk);
        default input #1step output #2;
        input srst, en, req, grant;
    endclocking

    modport DRIVER  (clocking drv_cb, input aclk, aresetn);
    modport MONITOR (clocking mon_cb, input aclk, aresetn);

endinterface
