`default_nettype none

module hotp (
    input wire clk,
    input wire rst_n,
    input wire in,
    output wire out,
    output wire [8:0] debug
);

    reg [2:0] stage;
    reg [6:0] round;
    reg [4:0] step;
    reg [3:0] index;

    wire msg_out;
    hmac_block block (
        .clk,
        .stage(stage[1:0]),
        .round,
        .step,
        .main_in(in),
        .msg_out,
        .debug(debug[6:0])
    );

    reg [39:0] digest;
    wire [11:0] sel_from = (60 - index) << 3;
    wire [11:0] sel_to = ((64 - index) << 3) - 2;
    wire [39:0] digest_rol = {digest[38:0], digest[39]};
    assign out = digest[0];

    integer i;

    always @(posedge clk) begin
        if (!rst_n) begin
            {stage, round, step} <= 0;
        end else begin
            {round, step} <= {round, step} + 1;
            if (round == 84 && step == 31) begin
                round <= 0;
                stage <= stage + 1;
            end
            if (stage == 4 && round >= 11 && round <= 15) begin
                if ({round, step} >= 352 && {round, step} <= 355) begin
                    index <= {msg_out, index[3:1]};
                end
                if ({round, step} >= sel_from && {round, step} <= sel_to) begin
                    digest <= {9'b0, msg_out, digest[30:1]};
                end
            end
            if (stage == 4 && (round == 16 || round == 17 && step <= 7)) begin
                for (i=0; i<10; i=i+1) begin
                    if ({round[0], step} >= 4*i+4 && digest_rol[4*i+:4] >= 5) begin
                        digest[4*i+:4] <= digest_rol[4*i+:4] + 3;
                    end else begin
                        digest[4*i+:4] <= digest_rol[4*i+:4];
                    end
                end
                if (round == 17 && step == 7) digest <= digest_rol;
            end
            if (stage == 4 && round == 18) begin
                digest <= {digest[0], digest[31:1]};
            end
            if (stage == 5) round <= 0;
        end
    end

    assign debug[8:7] = {msg_out, round[2]};

endmodule

