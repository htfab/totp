`default_nettype none

module hmac_block (
    input wire clk,
    input wire [1:0] stage,
    input wire [6:0] round,
    input wire [4:0] step,
    input wire main_in,
    output wire msg_out,
    output wire [6:0] debug
);

    wire [4:0] magic_sel = {
        stage == 0,
        stage == 2,
        stage == 1 && round == 2 || stage == 3 && round == 5,
        stage == 1 && round == 15,
        stage == 3 && round == 15
    };

    wire magic_out;
    hmac_magic magic (
        .sel(magic_sel),
        .step,
        .out(magic_out)
    );

    wire msg_in;
    hmac_mixer mixer (
        .clk,
        .stage,
        .round,
        .step,
        .in(main_in),
        .feedback(msg_out),
        .out(msg_in)
    );

    wire w_in =
        (stage == 0 || stage == 2 ? main_in ^ magic_out : 0) |
        (stage == 1 && round <= 1 || stage == 3 && round <= 4 ? msg_in : 0) |
        (stage == 1 && round >= 2 || stage == 3 && round >= 5 ? magic_out : 0);

    wire init_out;
    wire a_in = (stage == 0 || stage == 2) ? init_out : msg_out;
    wire h_in = (stage == 0 || stage == 2) ? msg_in : init_out;

    sha1_block sha1 (
        .clk,
        .round,
        .step,
        .w_in,
        .a_in,
        .h_in,
        .init_out,
        .h_out(msg_out),
        .debug(debug[1:0])
    );

    assign debug[6:2] = {init_out, msg_in, w_in, a_in, h_in};

endmodule

