// Multiplexes I/Q streams between Bypass, 8-bit noise-shaped packing, and 12-bit burst packing.
// Handles endianness alignment for Little-Endian DMA and prevents streaming state collisions.

module cs12_8mux #(
    parameter DATA_WIDTH = 16
) (
    input                       clk,
    input                       rst_n,
    input      [DATA_WIDTH-1:0] I0,
    input      [DATA_WIDTH-1:0] Q0,
    input                       valid_in,
    input                       Enable0,
    input                       Enable1,
    input                       zero_count,

    output reg [DATA_WIDTH-1:0] data_out0,
    output reg [DATA_WIDTH-1:0] data_out1,
    output reg                  valid_out,
    output reg                  burst_sync,
    output reg                  frame_start,
    output                      Enable_O1,
    output                      Enable_O2
);

    reg [95:0] ibuf_a;
    reg [95:0] ibuf_b;
    reg [95:0] qbuf_a;
    reg [95:0] qbuf_b;

    reg        active_buffer;
    reg [3:0]  in_count;
    reg [2:0]  out_count;
    reg        burst_pending;
    reg        burst_pending_r;
    reg        synced;

    reg signed [12:0] err_i;
    reg signed [12:0] err_q;

    // CS8 noise-shaped rounding. All operands are signed: a concatenation or a
    // part-select is unsigned in Verilog and would turn the whole expression
    // unsigned (err_i would then be zero-extended instead of sign-extended).
    wire signed [13:0] acc_i_w = $signed({{2{I0[11]}}, I0[11:0]}) + err_i;
    wire signed [13:0] acc_q_w = $signed({{2{Q0[11]}}, Q0[11:0]}) + err_q;

    // acc / 16 rounded half up
    wire signed [8:0] rnd_i_w = (acc_i_w >>> 4) + $signed({1'b0, acc_i_w[3]});
    wire signed [8:0] rnd_q_w = (acc_q_w >>> 4) + $signed({1'b0, acc_q_w[3]});

    wire signed [7:0] out_i_w = (rnd_i_w > 9'sd127) ? 8'sd127 :
                                (rnd_i_w < -9'sd128) ? -8'sd128 :
                                rnd_i_w[7:0];

    wire signed [7:0] out_q_w = (rnd_q_w > 9'sd127) ? 8'sd127 :
                                (rnd_q_w < -9'sd128) ? -8'sd128 :
                                rnd_q_w[7:0];

    wire signed [12:0] err_i_next = acc_i_w - ($signed({{5{out_i_w[7]}}, out_i_w}) <<< 4);
    wire signed [12:0] err_q_next = acc_q_w - ($signed({{5{out_q_w[7]}}, out_q_w}) <<< 4);

    assign Enable_O1 = (Enable0 | Enable1);
    assign Enable_O2 = Enable1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ibuf_a          <= 96'h0;
            ibuf_b          <= 96'h0;
            qbuf_a          <= 96'h0;
            qbuf_b          <= 96'h0;
            in_count        <= 4'd0;
            out_count       <= 3'd0;
            active_buffer   <= 1'b0;
            burst_pending   <= 1'b0;
            burst_pending_r <= 1'b0;
            data_out0       <= 16'h0;
            data_out1       <= 16'h0;
            valid_out       <= 1'b0;
            burst_sync      <= 1'b0;
            frame_start     <= 1'b0;
            synced          <= 1'b0;
            err_i           <= 13'sd0;
            err_q           <= 13'sd0;
        end else begin
            valid_out       <= 1'b0;
            frame_start     <= 1'b0;
            burst_sync      <= burst_pending && !burst_pending_r;
            burst_pending_r <= burst_pending;

            case ({Enable0, Enable1})
                2'b11: begin
                    err_i  <= 13'sd0;
                    err_q  <= 13'sd0;
                    synced <= 1'b0;
                    if (valid_in) begin
                        data_out0 <= I0;
                        data_out1 <= Q0;
                        valid_out <= 1'b1;
                    end
                end

                2'b10: begin
                    synced <= 1'b0;
                    if (valid_in) begin
                        data_out0 <= {out_q_w, out_i_w};
                        data_out1 <= 16'h0;
                        valid_out <= 1'b1;
                        err_i     <= err_i_next;
                        err_q     <= err_q_next;
                    end
                end

                2'b01: begin
                    err_i <= 13'sd0;
                    err_q <= 13'sd0;

                    if (zero_count) begin
                        ibuf_a          <= 96'h0;
                        ibuf_b          <= 96'h0;
                        qbuf_a          <= 96'h0;
                        qbuf_b          <= 96'h0;
                        in_count        <= 4'd0;
                        active_buffer   <= 1'b0;
                        burst_pending   <= 1'b0;
                        burst_pending_r <= 1'b0;
                        synced          <= 1'b0;
                    end else begin
                        if (burst_pending && !burst_pending_r) begin
                            synced <= 1'b1;
                        end
                    end

                    if (!zero_count && valid_in) begin
                        if (!active_buffer) begin
                            ibuf_a <= {ibuf_a[83:0], I0[11:0]};
                            qbuf_a <= {qbuf_a[83:0], Q0[11:0]};
                        end else begin
                            ibuf_b <= {ibuf_b[83:0], I0[11:0]};
                            qbuf_b <= {qbuf_b[83:0], Q0[11:0]};
                        end

                        if (in_count == 4'd7) begin
                            in_count      <= 4'd0;
                            active_buffer <= ~active_buffer;
                            burst_pending <= 1'b1;
                        end else begin
                            in_count <= in_count + 1'b1;
                        end
                    end

                    if (burst_pending_r) begin
                        valid_out   <= synced;
                        frame_start <= synced && (out_count == 3'd0);

                        if (active_buffer) begin
                            data_out0 <= {ibuf_a[87:80], ibuf_a[95:88]};
                            data_out1 <= {qbuf_a[87:80], qbuf_a[95:88]};
                            ibuf_a    <= {ibuf_a[79:0], 16'h0};
                            qbuf_a    <= {qbuf_a[79:0], 16'h0};
                        end else begin
                            data_out0 <= {ibuf_b[87:80], ibuf_b[95:88]};
                            data_out1 <= {qbuf_b[87:80], qbuf_b[95:88]};
                            ibuf_b    <= {ibuf_b[79:0], 16'h0};
                            qbuf_b    <= {qbuf_b[79:0], 16'h0};
                        end

                        if (out_count == 3'd5) begin
                            out_count       <= 3'd0;
                            burst_pending   <= 1'b0;
                            burst_pending_r <= 1'b0;
                        end else begin
                            out_count <= out_count + 1'b1;
                        end
                    end
                end

                default: begin
                    ibuf_a          <= 96'h0;
                    ibuf_b          <= 96'h0;
                    qbuf_a          <= 96'h0;
                    qbuf_b          <= 96'h0;
                    in_count        <= 4'd0;
                    out_count       <= 3'd0;
                    active_buffer   <= 1'b0;
                    burst_pending   <= 1'b0;
                    burst_pending_r <= 1'b0;
                    synced          <= 1'b0;
                    data_out0       <= 16'h0;
                    data_out1       <= 16'h0;
                    err_i           <= 13'sd0;
                    err_q           <= 13'sd0;
                end
            endcase
        end
    end

endmodule
