`default_nettype none

module seg_magic (
    input wire [3:0] digit,
    output wire [6:0] segments
);

    wire [69:0] segdata = 70'h37ff0ff76e69f6c33f;
    assign segments = segdata[digit*7 +: 7];

endmodule

