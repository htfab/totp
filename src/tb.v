`default_nettype none
`timescale 1ns/1ps

/*
this testbench just instantiates the module and makes some convenient wires
that can be driven / tested by the cocotb test.py
*/

module tb (
    // testbench is controlled by test.py
    input clk,
    input rst_n,
    input data,
    input key_en,
    input msg_en,
    input [2:0] sel,
    input alt_sel,
    input dir_sel,
    input hotp_rst_n,
    input hotp_in,
    output hotp_out,
    output ready,
    output [6:0] segs,
    output [3:0] bcd,
    output [3:0] debug,
    output [7:0] alt_debug,
    output [7:0] dirs
   );

    // this part dumps the trace to a vcd file that can be viewed with GTKWave
    initial begin
        $dumpfile ("tb.vcd");
        $dumpvars (0, tb);
        #1;
    end

    // wire up the inputs and outputs
    wire [7:0] ui_in, uo_out, uio_in, uio_out, uio_oe;
    wire ena;

    assign ena = 1'b1;
    assign ui_in[0] = data;
    assign ui_in[1] = key_en;
    assign ui_in[2] = msg_en;
    assign ui_in[5:3] = sel;
    assign ui_in[6] = alt_sel;
    assign ui_in[7] = dir_sel;
    assign uio_in[0] = hotp_rst_n;
    assign uio_in[1] = hotp_in;
    assign uio_in[7:2] = 0;
    assign segs = uo_out[6:0];
    assign ready = uo_out[7];
    assign bcd = uio_out[7:4];
    assign debug = uio_out[3:0];
    assign alt_debug = uio_out;
    assign dirs = uio_oe;

    // instantiate the DUT
    tt_um_htfab_totp dut (
        `ifdef GL_TEST
            .vccd1( 1'b1),
            .vssd1( 1'b0),
        `endif
        .ui_in,
        .uo_out,
        .uio_in,
        .uio_out,
        .uio_oe,
        .ena,
        .clk,
        .rst_n
        );

endmodule
