`timescale 1ns/1ps
// Self-checking test of the CS8 path of cs12_8mux (Enable0 = 1, Enable1 = 0).
// Each valid input sample must give data_out0 = {Q8, I8}, where for each
// component, with the error e carried over from the previous sample:
//   acc = x[11:0] (signed) + e,  out = clamp(floor((acc + 8) / 16), -128, 127),
//   e   = acc - 16 * out.
// Covers every 12-bit input value and 2 M random samples with random valid.
// Run: iverilog -g2005 -o tb cs12_cs8mux_cs8_tb.v ../cs12_cs8mux.v && vvp tb
module cs12_cs8mux_cs8_tb;
    reg clk = 0, rst_n = 0, valid_in = 0;
    reg [15:0] I0 = 0, Q0 = 0;
    wire [15:0] d0, d1;
    wire v, fs, bs, e1, e2;
    cs12_8mux dut(.clk(clk), .rst_n(rst_n), .I0(I0), .Q0(Q0), .valid_in(valid_in), .Enable0(1'b1),
        .Enable1(1'b0), .zero_count(1'b0), .data_out0(d0), .data_out1(d1), .valid_out(v),
        .burst_sync(bs), .frame_start(fs), .Enable_O1(e1), .Enable_O2(e2));
    always #5 clk = ~clk;

    integer err_i = 0, err_q = 0, exp_i, exp_q, n = 0, bad = 0, i;
    reg pending = 0;

    function integer floordiv16(input integer a);
        floordiv16 = (a >= 0) ? a / 16 : -((-a + 15) / 16);
    endfunction

    task model(input [11:0] x, inout integer err, output integer out);
        integer acc;
        begin
            acc = $signed(x) + err;
            out = floordiv16(acc + 8);
            if (out > 127) out = 127;
            if (out < -128) out = -128;
            err = acc - 16 * out;
        end
    endtask

    always @(posedge clk) begin
        if (pending) begin
            n = n + 1;
            if (!v || $signed(d0[7:0]) != exp_i || $signed(d0[15:8]) != exp_q || d1 != 0) begin
                bad = bad + 1;
                if (bad < 5) $display("MISMATCH sample %0d: got %h valid %b, expected I %0d Q %0d",
                                      n, d0, v, exp_i, exp_q);
            end
        end
        pending = rst_n && valid_in;
        if (pending) begin
            model(I0[11:0], err_i, exp_i);
            model(Q0[11:0], err_q, exp_q);
        end
    end

    initial begin
        repeat (3) @(negedge clk); rst_n = 1;
        for (i = 0; i < 4096 * 4; i = i + 1) begin
            @(negedge clk); valid_in = 1; I0 = {4'h0, i[11:0]}; Q0 = {4'h0, i[13:2]};
        end
        for (i = 0; i < 2000000; i = i + 1) begin
            @(negedge clk); valid_in = ($random & 3) != 0; I0 = $random; Q0 = $random;
        end
        @(negedge clk); valid_in = 0; @(negedge clk);
        $display("%0d CS8 samples checked, %0d mismatches", n, bad);
        if (bad == 0) $display("PASS"); else $display("FAIL");
        $finish;
    end
endmodule
