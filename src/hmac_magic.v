`default_nettype none

module hmac_magic (
    input wire [4:0] sel,
    input wire [4:0] step,
    output wire out
);

    wire [31:0] val =
        (sel[4] ? 32'h36363636 : 0) |
        (sel[3] ? 32'h5c5c5c5c : 0) |
        (sel[2] ? 32'h80000000 : 0) |
        (sel[1] ? 32'h00000240 : 0) |
        (sel[0] ? 32'h000002a0 : 0);
    assign out = val[step];

endmodule

