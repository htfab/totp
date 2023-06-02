`default_nettype none

module sha1_mixer (
    input wire clk,
    input wire [4:0] step,
    input wire w_in,
    input wire w_en,
    input wire a_in,
    input wire a_en,
    input wire c_rot,
    input wire [3:0] f_sel,
    input wire k_in,
    input wire h_in,
    output wire h_out,
    output wire [1:0] debug
);

    reg [31:0] a, b, c, d, e;
    reg [511:0] w;
    reg [2:0] a_carry;
    reg h_carry;
    reg t;

    wire w_fb = w[0] ^ w[64] ^ w[256] ^ w[416];

    wire f =
        (f_sel[3] ? b[0] & c[0] | ~b[0] & d[0] : 0) |
        (f_sel[2] || f_sel[0] ? b[0] ^ c[0] ^ d[0] : 0) |
        (f_sel[1] ? b[0] & c[0] | b[0] & d[0] | c[0] & d[0] : 0);

    wire h_cnext;
    assign {h_cnext, h_out} = h_in + e[0] + h_carry;

    always @(posedge clk) begin

        {t, w[510:0]} <= {w_fb, w[511:1]};
        if (w_en) begin
            w[511] <= w_in;
        end else begin
            w[511] <= t;
            if (step == 31) w[480] <= w_fb;
        end

        {a[30:0], b[30:0], c[30], c[28:0], d[30:0], e[30:0]} <= {a[31:1], b[31:1], c[31], c[29:1], d[31:1], e[31:1]};

        if (a_en) begin
            a[31] <= a_in;
        end else begin
            {a_carry, a[31]} <= (step <= 4 ? a[27] : b[27]) + f + e[0] + k_in + w[0] + a_carry;
        end
        b[31] <= a[0];
        c[31] <= c_rot && step >= 2 ? c[30] : b[0];
        c[29] <= c_rot && step >= 2 ? b[0] : c[30];
        d[31] <= c[0];
        e[31] <= d[0];
        h_carry <= h_cnext;

        if (step == 31) begin
            a_carry <= 0;
            h_carry <= 0;
        end

    end

    assign debug = {w[0], a[0]};

endmodule

