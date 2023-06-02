`default_nettype none

module stream (
    input wire clk,
    input wire rst_n,
    input wire data,
    input wire key_en,
    input wire msg_en,
    input wire [2:0] sel,
    input wire hotp_out,
    output reg ready,
    output reg [3:0] bcd,
    output reg hotp_rst_n,
    output reg hotp_in,
    output wire [1:0] debug
);

    // the code assumes
    //   KEY_LEN <= 512, is a multiple of 32 and a divisor of 5440
    //   MSG_LEN <= 64, is a multiple of 32
    // remember to change the length of key_counter
    `define KEY_LEN 160
    `define MSG_LEN 64

    reg [`KEY_LEN-1:0] key_buf;
    reg [`MSG_LEN-1:0] msg_buf;
    reg [31:0] digest;
    reg [2:0] state;
    reg [1:0] key_state;
    reg [1:0] msg_state;
    reg [7:0] key_counter;
    reg [12:0] counter;

    wire [4:0] rev_index = {~counter[3:0], 1'b1};

    always @(posedge clk) begin
        key_buf <= {key_buf[0], key_buf[`KEY_LEN-1:1]};
        key_counter <= key_counter + 1;
        if (key_counter == `KEY_LEN-1) key_counter <= 0;
        if (!rst_n) begin
            {state, key_state, msg_state, key_counter, counter, ready, bcd, hotp_rst_n, hotp_in} <= 0;
        end else begin
            if (state == 1 || key_en || msg_en) begin
                state <= 1;
                ready <= 0;
                hotp_rst_n <= 0;
                if ((state != 1 || key_state <= 1) && key_en) begin
                    key_state <= 3;
                    key_buf[`KEY_LEN-1] <= data;
                    key_counter <= 1;
                end else if (key_state == 1) begin
                    if (key_counter) begin
                        key_buf[`KEY_LEN-1] <= 1'b0;
                    end else begin
                        key_state <= 0;
                    end
                end else if (key_state == 2) begin
                    if (!key_en) key_state <= 0;
                end else if (key_state == 3) begin
                    if (key_en && key_counter) begin
                        key_buf[`KEY_LEN-1] <= data;
                    end else if (key_en && !key_counter) begin
                        key_state <= 2;
                    end else if (key_counter) begin
                        key_buf[`KEY_LEN-1] <= 1'b0;
                        key_state <= 1;
                    end else begin
                        key_state <= 0;
                    end
                end
                if ((state != 1 || msg_state <= 1) && msg_en) begin
                    msg_state <= 3;
                    msg_buf <= {data, msg_buf[`MSG_LEN-1:1]};
                    counter <= 1;
                end else if (msg_state == 1) begin
                    if (counter < `MSG_LEN) begin
                        msg_buf <= {1'b0, msg_buf[`MSG_LEN-1:1]};
                        counter <= counter + 1;
                    end else begin
                        msg_state <= 0;
                    end
                end else if (msg_state == 2) begin
                    if (!msg_en) msg_state <= 0;
                end else if (msg_state == 3) begin
                    if (msg_en && counter < `MSG_LEN) begin
                        msg_buf <= {data, msg_buf[`MSG_LEN-1:1]};
                        counter <= counter + 1;
                    end else if (msg_en) begin
                        msg_state <= 2;
                    end else if (counter < `MSG_LEN) begin
                        msg_buf <= {1'b0, msg_buf[`MSG_LEN-1:1]};
                        counter <= counter + 1;
                        msg_state <= 1;
                    end else begin
                        msg_state <= 0;
                    end
                end
                if (key_state == 0 && msg_state == 0 && !key_en && !msg_en) begin
                    if (key_counter == `KEY_LEN-1) begin
                        state <= 2;
                        counter <= 0;
                    end
                end
            end else if (state == 2) begin
                hotp_rst_n <= 1;
                counter <= counter + 1;
                if (counter < `KEY_LEN) begin
                    if (counter[4]) begin
                        hotp_in <= key_buf[`KEY_LEN-32+rev_index];
                    end else begin
                        hotp_in <= key_buf[rev_index];
                    end
                end else if (counter < 512) begin
                    hotp_in <= 1'b0;
                end else if (counter == 2719) begin
                    state <= 3;
                    counter <= 0;
                end
            end else if (state == 3) begin
                counter <= counter + 1;
                if (counter < `MSG_LEN) begin
                    msg_buf <= {msg_buf[`MSG_LEN-2:0], msg_buf[`MSG_LEN-1]};
                    hotp_in <= msg_buf[31];
                end else if (counter < 64) begin
                    hotp_in <= 1'b0;
                end else if (counter == 2719) begin
                    state <= 4;
                    counter <= 0;
                end
            end else if (state == 4) begin
                counter <= counter + 1;
                if (counter < `KEY_LEN) begin
                    if (counter[4]) begin
                        hotp_in <= key_buf[`KEY_LEN-32+rev_index];
                    end else begin
                        hotp_in <= key_buf[rev_index];
                    end
                end else if (counter < 512) begin
                    hotp_in <= 1'b0;
                end else if (counter == 6016) begin
                    state <= 5;
                    counter <= 0;
                end
            end else if (state == 5) begin
                counter <= counter + 1;
                if (counter < 32) begin
                    digest <= {hotp_out, digest[31:1]};
                end else begin
                    state <= 0;
                    ready <= 1;
                    hotp_rst_n <= 0;
                end              
            end
            bcd <= digest[4*sel +: 4];
        end
    end

    assign debug = {state[0], counter[5]};

endmodule

