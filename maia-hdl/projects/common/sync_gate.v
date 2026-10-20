// Clocked replacement for mux_enable.v (which is purely combinational). Used by sync_clocked.tcl.
// DRAFT: simulated with iverilog (sim/tb_sync_gate.v) only; not built in Vivado, not tested on hardware.
//
//   clk          sample clock (util_ad9361_divclk), the clock of util_ad9361_adc_pack and IQBurst
//   arm_master   AXI register bit (bit 2 of up_adc_gpio_out, asynchronous to clk): 0->1 fires the sync
//   sync_in_pad  asynchronous input from the other board (pad_6)
//   sync_out     to the pad (pad_4): launched from a clk flop, so the edge is aligned to clk
//   is_slave     quasi-static register bit (bit 1): gate on sync_in_pad instead of the master's own sync
//   phase_sel    quasi-static (bit 3): 0 = sample sync_in_pad on the rising clk edge, 1 = on the falling edge
//                (moves the point where the edge becomes "one sample late" by half a clock period)
//   master_delay quasi-static (bits 8:4): EXTRA clk cycles of delay on the master's own gate, on top of the
//                BASE_DELAY that matches the slave's synchroniser depth. 0 (register reset value) = both
//                gates open on the same cycle when the pad delay is below the sampling boundary.
//   out_*        registered gated enables for util_ad9361_adc_pack / IQBurst sync_in (same latency on master and slave)
//   edge_first_half  status: pad edge seen by the falling-edge sampler one half cycle earlier (not connected in the Tcl)
module sync_gate #(
    parameter BASE_DELAY = 2
) (
    input  wire       clk,
    input  wire       is_slave,
    input  wire       arm_master,
    input  wire       sync_in_pad,
    input  wire       phase_sel,
    input  wire [4:0] master_delay,
    input  wire       ps_i0, ps_q0, ps_i1, ps_q1,
    output wire       sync_out,
    output reg        out_i0, out_q0, out_i1, out_q1,
    output wire       edge_first_half
);
    // quasi-static configuration bits come from the AXI clock domain: synchronise them into clk (2 flops each)
    // instead of feeding the gate logic directly (a direct path failed timing by 2.4 ns in the first build).
    // They are written well before a trigger is armed, so bit-to-bit skew while they change is harmless.
    (* ASYNC_REG = "TRUE" *) reg [6:0] cfg_s0 = 7'd0;
    (* ASYNC_REG = "TRUE" *) reg [6:0] cfg_s1 = 7'd0;
    always @(posedge clk) begin
        cfg_s0 <= {master_delay, phase_sel, is_slave};
        cfg_s1 <= cfg_s0;
    end
    wire       is_slave_s     = cfg_s1[0];
    wire       phase_sel_s    = cfg_s1[1];
    wire [4:0] master_delay_s = cfg_s1[6:2];

    // master: synchronise the (asynchronous) register bit, then launch sync_out from a clk flop
    (* ASYNC_REG = "TRUE" *) reg [1:0] arm_s = 2'b00;
    reg sync_out_r = 1'b0;
    always @(posedge clk) begin
        arm_s      <= {arm_s[0], arm_master};
        sync_out_r <= arm_s[1];
    end
    assign sync_out = sync_out_r;

    // master's own gate: sync_out_r delayed by BASE_DELAY + master_delay clk cycles (>= 1)
    reg [32:0] msr = 33'd0;
    always @(posedge clk) msr <= {msr[31:0], sync_out_r};
    wire [5:0] eff_delay   = BASE_DELAY + master_delay_s;
    wire       master_gate = (eff_delay == 6'd0) ? sync_out_r : msr[eff_delay - 6'd1];

    // slave: two synchroniser paths for the pad (rising-edge and falling-edge sampling)
    (* ASYNC_REG = "TRUE" *) reg in_s0 = 1'b0;
    reg in_s1 = 1'b0;
    (* ASYNC_REG = "TRUE" *) reg in_n0 = 1'b0;
    reg in_n0_p = 1'b0, in_n1 = 1'b0, in_n2 = 1'b0;
    always @(posedge clk) begin
        in_s0   <= sync_in_pad;
        in_s1   <= in_s0;
        in_n0_p <= in_n0;
        in_n1   <= in_n0;
        in_n2   <= in_n1;
    end
    always @(negedge clk) in_n0 <= sync_in_pad;
    assign edge_first_half = in_n0_p;

    wire slave_gate = phase_sel_s ? in_n2 : in_s1;
    wire gate       = is_slave_s ? slave_gate : master_gate;

    always @(posedge clk) begin
        out_i0 <= gate & ps_i0;
        out_q0 <= gate & ps_q0;
        out_i1 <= gate & ps_i1;
        out_q1 <= gate & ps_q1;
    end
endmodule
