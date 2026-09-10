`timescale 1ns/1ps

// Self-checking test for the fixed-TCXO complex NCO. It verifies exact bypass,
// the configuration apply CDC, RX positive rotation and TX negative rotation.
//
// Run from the repository root:
//   iverilog -g2012 -s iq_xo_corrector_tb -o iq_xo_corrector_tb.vvp \
//     projects/common/tb/iq_xo_corrector_tb.v \
//     projects/common/iq_xo_corrector.v \
//     adi-hdl/library/common/ad_dds_sine_cordic.v \
//     adi-hdl/library/common/ad_dds_cordic_pipe.v
//   vvp iq_xo_corrector_tb.vvp

module iq_xo_corrector_tb;
  reg clk = 1'b0;
  reg rst_n = 1'b0;
  always #5 clk = ~clk;

  reg [31:0] cfg_rx_ftw = 0;
  reg [31:0] cfg_tx_ftw = 0;
  reg [3:0] cfg_control = 0;

  reg rx_valid_in = 0;
  reg signed [15:0] rx_i0_in = 0, rx_q0_in = 0;
  reg signed [15:0] rx_i1_in = 0, rx_q1_in = 0;
  wire rx_valid_out;
  wire signed [15:0] rx_i0_out, rx_q0_out, rx_i1_out, rx_q1_out;

  reg tx_valid0_in = 0;
  reg tx_valid1_in = 0;
  reg signed [15:0] tx_i0_in = 0, tx_q0_in = 0;
  reg signed [15:0] tx_i1_in = 0, tx_q1_in = 0;
  wire tx_valid0_out;
  wire tx_valid1_out;
  wire signed [15:0] tx_i0_out, tx_q0_out, tx_i1_out, tx_q1_out;

  integer errors = 0;
  integer seen;
  integer k;
  integer di, dq;

  iq_xo_corrector dut (
    .clk(clk), .rst_n(rst_n),
    .cfg_rx_ftw(cfg_rx_ftw), .cfg_tx_ftw(cfg_tx_ftw),
    .cfg_control(cfg_control),
    .rx_valid_in(rx_valid_in),
    .rx_i0_in(rx_i0_in), .rx_q0_in(rx_q0_in),
    .rx_i1_in(rx_i1_in), .rx_q1_in(rx_q1_in),
    .rx_valid_out(rx_valid_out),
    .rx_i0_out(rx_i0_out), .rx_q0_out(rx_q0_out),
    .rx_i1_out(rx_i1_out), .rx_q1_out(rx_q1_out),
    .tx_valid0_in(tx_valid0_in), .tx_valid1_in(tx_valid1_in),
    .tx_i0_in(tx_i0_in), .tx_q0_in(tx_q0_in),
    .tx_i1_in(tx_i1_in), .tx_q1_in(tx_q1_in),
    .tx_valid0_out(tx_valid0_out), .tx_valid1_out(tx_valid1_out),
    .tx_i0_out(tx_i0_out), .tx_q0_out(tx_q0_out),
    .tx_i1_out(tx_i1_out), .tx_q1_out(tx_q1_out)
  );

  task check_near;
    input integer got_i;
    input integer got_q;
    input integer exp_i;
    input integer exp_q;
    begin
      di = got_i - exp_i;
      dq = got_q - exp_q;
      if (di < 0) di = -di;
      if (dq < 0) dq = -dq;
      if (di > 12 || dq > 12) begin
        errors = errors + 1;
        $display("MISMATCH got=(%0d,%0d) expected=(%0d,%0d)",
                 got_i, got_q, exp_i, exp_q);
      end
    end
  endtask

  initial begin
    repeat (5) @(posedge clk);
    rst_n = 1'b1;
    repeat (3) @(posedge clk);

    // Reset defaults must be a bit-exact bypass.
    @(negedge clk);
    rx_i0_in = 16'sd1234; rx_q0_in = -16'sd2345;
    rx_i1_in = -16'sd3210; rx_q1_in = 16'sd4321;
    rx_valid_in = 1'b1;
    @(negedge clk);
    rx_valid_in = 1'b0;
    wait (rx_valid_out === 1'b1);
    #1;
    if (rx_i0_out !== 16'sd1234 || rx_q0_out !== -16'sd2345 ||
        rx_i1_out !== -16'sd3210 || rx_q1_out !== 16'sd4321) begin
      errors = errors + 1;
      $display("BYPASS MISMATCH (%0d,%0d) (%0d,%0d)",
               rx_i0_out, rx_q0_out, rx_i1_out, rx_q1_out);
    end
    wait (rx_valid_out === 1'b0);

    // Enable RX, reset phase and advance by +1/4 turn per valid sample.
    cfg_rx_ftw = 32'h4000_0000;
    cfg_control = 4'b1101; // phase reset, toggle=1, RX enable
    repeat (12) @(posedge clk);
    @(negedge clk);
    rx_i0_in = 16'sd10000; rx_q0_in = 0;
    rx_i1_in = 0; rx_q1_in = 16'sd10000;
    for (k = 0; k < 4; k = k + 1) begin
      rx_valid_in = 1'b1;
      @(negedge clk);
      rx_valid_in = 1'b0;
      @(negedge clk);
    end

    seen = 0;
    while (seen < 4) begin
      @(posedge clk); #1;
      if (rx_valid_out) begin
        case (seen)
          0: begin check_near(rx_i0_out, rx_q0_out,  10000,      0);
                   check_near(rx_i1_out, rx_q1_out,      0,  10000); end
          1: begin check_near(rx_i0_out, rx_q0_out,      0,  10000);
                   check_near(rx_i1_out, rx_q1_out, -10000,      0); end
          2: begin check_near(rx_i0_out, rx_q0_out, -10000,      0);
                   check_near(rx_i1_out, rx_q1_out,      0, -10000); end
          3: begin check_near(rx_i0_out, rx_q0_out,      0, -10000);
                   check_near(rx_i1_out, rx_q1_out,  10000,      0); end
        endcase
        seen = seen + 1;
      end
    end

    // Toggle apply back to zero: TX enabled at -1/4 turn/sample, RX bypassed.
    cfg_tx_ftw = 32'hc000_0000;
    cfg_control = 4'b1010; // phase reset, toggle=0, TX enable
    repeat (12) @(posedge clk);
    @(negedge clk);
    tx_i0_in = 16'sd10000; tx_q0_in = 0;
    tx_i1_in = 0; tx_q1_in = 16'sd10000;
    tx_valid0_in = 1'b1;
    tx_valid1_in = 1'b1;
    repeat (4) @(negedge clk);
    tx_valid0_in = 1'b0;
    tx_valid1_in = 1'b0;

    seen = 0;
    while (seen < 4) begin
      @(posedge clk); #1;
      if (tx_valid0_out) begin
        case (seen)
          0: check_near(tx_i0_out, tx_q0_out,  10000,      0);
          1: check_near(tx_i0_out, tx_q0_out,      0, -10000);
          2: check_near(tx_i0_out, tx_q0_out, -10000,      0);
          3: check_near(tx_i0_out, tx_q0_out,      0,  10000);
        endcase
        seen = seen + 1;
      end
    end

    // Channel 1 valid must remain independent when channel 0 is continuous
    // (the TX interpolation mode has exactly this relationship).
    @(negedge clk);
    tx_i0_in = 16'sd2000; tx_q0_in = 0;
    tx_i1_in = 16'sd3000; tx_q1_in = 0;
    tx_valid0_in = 1'b1;
    tx_valid1_in = 1'b0;
    repeat (3) @(negedge clk);
    tx_valid1_in = 1'b1;
    @(negedge clk);
    tx_valid1_in = 1'b0;
    repeat (3) @(negedge clk);
    tx_valid0_in = 1'b0;

    seen = 0;
    while (seen < 7) begin
      @(posedge clk); #1;
      if (tx_valid0_out) begin
        seen = seen + 1;
        if (tx_valid1_out !== (seen == 4)) begin
          errors = errors + 1;
          $display("TX VALID MISMATCH sample=%0d valid1=%b", seen,
                   tx_valid1_out);
        end
      end
    end

    if (errors == 0)
      $display("IQ XO CORRECTOR TEST: PASS");
    else begin
      $display("IQ XO CORRECTOR TEST: FAIL (%0d errors)", errors);
      $fatal(1, "IQ XO corrector regression detected");
    end
    $finish;
  end

endmodule
