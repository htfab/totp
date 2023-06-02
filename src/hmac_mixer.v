`default_nettype none

module hmac_mixer (
    input wire clk,
    input wire [1:0] stage,
    input wire [6:0] round,
    input wire [4:0] step,
    input wire in,
    input wire feedback,
    output wire out
);

    reg [159:0] msg;

    wire msg_rev =
        (round == 0 ? msg[128] : 0) | 
        (round == 1 ? msg[64] : 0) |
        (round == 2 ? msg[0] : 0) |
        (round == 3 ? msg[96] : 0) |
        (round == 4 ? msg[32] : 0) |
        (round >= 5 ? msg[0] : 0);
    assign out = stage == 1 ? in : msg_rev;

    always @(posedge clk) begin
        if (round <= 4) begin
            msg[159] <= stage == 1 ? in : msg[0];
            msg[158:0] <= msg[159:1];
        end
        if (round >= 11 && round <= 15) begin
            msg[159] <= feedback;
            msg[158:0] <= msg[159:1];
        end            
    end

endmodule

