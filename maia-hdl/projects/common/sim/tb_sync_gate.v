`timescale 1ns/100ps
// Master and slave gates on one clock; the pad edge reaches the slave d ns after the master's sync_out
// (d folds together wire delay and the phase between the two boards' sample clocks).
module tb_sync_gate;
    localparam real T = 100.0;          // 10 MS/s sample clock
    reg clk = 0; always #(T/2) clk = ~clk;
    reg arm = 0, phase_sel = 0; real d = 0.0;
    wire so_m, so_s, pad, mi0, mq0, mi1, mq1, si0, sq0, si1, sq1, h_m, h_s;
    reg [4:0] mdelay = 5'd0;   // extra delay on top of BASE_DELAY = 2

    sync_gate master (.clk(clk), .is_slave(1'b0), .arm_master(arm), .sync_in_pad(1'b0), .phase_sel(1'b0), .master_delay(mdelay),
                      .ps_i0(1'b1), .ps_q0(1'b1), .ps_i1(1'b1), .ps_q1(1'b1), .sync_out(so_m),
                      .out_i0(mi0), .out_q0(mq0), .out_i1(mi1), .out_q1(mq1), .edge_first_half(h_m));
    sync_gate slave  (.clk(clk), .is_slave(1'b1), .arm_master(1'b0), .sync_in_pad(pad), .phase_sel(phase_sel), .master_delay(5'd0),
                      .ps_i0(1'b1), .ps_q0(1'b1), .ps_i1(1'b1), .ps_q1(1'b1), .sync_out(so_s),
                      .out_i0(si0), .out_q0(sq0), .out_i1(si1), .out_q1(sq1), .edge_first_half(h_s));

    reg pad_r = 0; assign pad = pad_r;
    always @(so_m) pad_r <= #(d) so_m;                       // wire / board-to-board clock phase delay

    real t_launch, t_m, t_s; integer ps, k, di; real step;
    always @(posedge so_m) t_launch = $realtime;
    always @(posedge mi0)  t_m = $realtime;
    always @(posedge si0)  t_s = $realtime;
    task run_one; input integer sel; input real dd; input real arm_off; begin
        phase_sel = sel; d = dd; arm = 0; #(5*T);
        t_launch = -1; t_m = -1; t_s = -1;
        #(arm_off); arm = 1;                                  // asynchronous register write
        #(10*T);
        $display("phase_sel=%0d d=%5.1f ns arm_off=%4.1f | sync_out launched at %7.1f (on a clk edge: %0s) | master gate +%0.0f ns, slave gate +%0.0f ns, skew %0.0f ns",
                 sel, dd, arm_off, t_launch, (t_launch - T/2 - T*$floor((t_launch - T/2 + 0.5)/T) < 0.5 && t_launch - T/2 - T*$floor((t_launch - T/2 + 0.5)/T) > -0.5) ? "yes" : "NO", t_m - t_launch, t_s - t_launch, t_s - t_m);
        arm = 0; #(6*T);
    end endtask

    initial begin #(300000.0); $display("WATCHDOG: simulation stuck"); $finish; end
    initial begin
        #(10*T);
        $display("--- launch alignment: arm_master written at random times, d = 20 ns, phase_sel = 0");
        for (k = 0; k < 4; k = k + 1) run_one(0, 20.0, 13.0*k + 3.7);
        $display("--- slave gate delay vs pad delay d (arm_off = 7.3 ns); a change of skew = pad edge crossed a sampling instant");
        for (ps = 0; ps < 2; ps = ps + 1)
            for (di = 0; di <= 14; di = di + 1) run_one(ps, 10.0*di, 7.3);
        $finish;
    end
endmodule
