`default_nettype none

module tt_um_htfab_totp (
  input wire [7:0] ui_in,
  output wire [7:0] uo_out,
  input wire [7:0] uio_in,
  output wire [7:0] uio_out,
  output wire [7:0] uio_oe,
  input wire ena,
  input wire clk,
  input wire rst_n
);

    wire data, key_en, msg_en, ready;
    wire hotp_rst_n, hotp_in, hotp_out;
    wire muxed_rst_n, muxed_in;
    wire [2:0] sel;
    wire [3:0] bcd;
    wire [6:0] segs;
    wire [1:0] stream_debug;
    wire [8:0] hotp_debug;

    stream stream (
        .clk,
        .rst_n,
        .data,
        .key_en,
        .msg_en,
        .sel,
        .hotp_out,
        .ready,
        .bcd,
        .hotp_rst_n,
        .hotp_in,
        .debug(stream_debug)
    );

    hotp hotp (
        .clk,
        .rst_n(muxed_rst_n),
        .in(muxed_in),
        .out(hotp_out),
        .debug(hotp_debug)
    );
    
    seg_magic seg (
        .digit(bcd),
        .segments(segs)
    );

    wire [3:0] debug = {hotp_debug[8], hotp_out, stream_debug};
    wire [7:0] alt_debug = hotp_debug[7:0];

    assign data = ui_in[0];
    assign key_en = ui_in[1];
    assign msg_en = ui_in[2];
    assign sel = ui_in[5:3];
    assign uo_out[6:0] = segs;
    assign uo_out[7] = ready;
    assign muxed_rst_n = ui_in[7] ? uio_in[0] : hotp_rst_n;
    assign muxed_in = ui_in[7] ? uio_in[1] : hotp_in;
    assign uio_out = ui_in[6] ? alt_debug : {bcd, debug};
    assign uio_oe = ui_in[7] ? 8'b11111100 : 8'b11111111;

endmodule
