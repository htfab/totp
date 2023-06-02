`default_nettype none

module sha1_magic (
    input wire [4:0] init_sel,
    input wire [3:0] round_sel,
    input wire [4:0] step,
    output wire init_out,
    output wire round_out
);

    wire [31:0] init_val =
        (init_sel[4] ? 32'hc3d2e1f0 : 0) |
        (init_sel[3] ? 32'h10325476 : 0) |
        (init_sel[2] ? 32'h98badcfe : 0) |
        (init_sel[1] ? 32'hefcdab89 : 0) |
        (init_sel[0] ? 32'h67452301 : 0);
    assign init_out = init_val[step];

    wire [31:0] round_val =
        (round_sel[3] ? 32'h5a827999 : 0) |
        (round_sel[2] ? 32'h6ed9eba1 : 0) |
        (round_sel[1] ? 32'h8f1bbcdc : 0) |
        (round_sel[0] ? 32'hca62c1d6 : 0);
    assign round_out = round_val[step];

endmodule

