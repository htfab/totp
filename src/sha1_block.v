`default_nettype none

module sha1_block (
    input wire clk,
    input wire [6:0] round,
    input wire [4:0] step,
    input wire w_in,
    input wire a_in,
    input wire h_in,
    output wire init_out,
    output wire h_out,
    output wire [1:0] debug
);

    wire [4:0] init_sel = {
        round == 11,
        round == 12,
        round == 13,
        round == 14,
        round == 15
    };

    wire [3:0] round_sel = {
        round >= 16 && round <= 35,
        round >= 36 && round <= 55,
        round >= 56 && round <= 75,
        round >= 76 || round <= 15
    };

    wire round_magic;
    sha1_magic magic (
        .init_sel,
        .round_sel,
        .step,
        .init_out(init_out),
        .round_out(round_magic)
    );

    sha1_mixer mixer (
        .clk,
        .step,
        .w_in,
        .w_en(round <= 15),
        .a_in,
        .a_en(round >= 11 && round <= 15),
        .c_rot(round >= 16 || round <= 10),
        .f_sel(round_sel),
        .k_in(round_magic),
        .h_in,
        .h_out,
        .debug
    );

endmodule

