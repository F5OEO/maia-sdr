`timescale 1ns/100ps

// Complex NCO used to compensate the RF frequency error caused by a fixed
// (non-voltage-tunable) 40 MHz oscillator on some LibreSDR variants.
//
// The block deliberately does not calculate its own tuning word. Software has
// the requested RF frequency and sample rate, and combines those with the
// frequency error measured by vctcxo_lock. The signed 32-bit words supplied
// here are phase turns/sample in Q0.32 format.
//
// cfg_* are written in the AXI clock domain. Software writes both FTWs and the
// enable bits first, then toggles cfg_control[2]. The toggle is synchronized
// more slowly than the data bus, so the complete configuration is captured as
// one coherent update in clk's domain. cfg_control[3] resets both phases when
// that update is applied.
//
// cfg_control[0] = RX correction enable
// cfg_control[1] = TX correction enable
// cfg_control[2] = apply toggle (invert for every update)
// cfg_control[3] = reset phase on this update
//
// A disabled direction is an exact, latency-matched bypass. The NCO phase only
// advances on valid samples, not on every fabric clock.

module iq_xo_corrector #(
  parameter integer DATA_WIDTH = 16,
  parameter integer PHASE_WIDTH = 32,
  parameter integer CORDIC_PHASE_WIDTH = 16,
  parameter integer COEFF_WIDTH = 16
) (
  input  wire                         clk,
  input  wire                         rst_n,

  input  wire [PHASE_WIDTH-1:0]       cfg_rx_ftw,
  input  wire [PHASE_WIDTH-1:0]       cfg_tx_ftw,
  input  wire [3:0]                   cfg_control,

  input  wire                         rx_valid_in,
  input  wire signed [DATA_WIDTH-1:0] rx_i0_in,
  input  wire signed [DATA_WIDTH-1:0] rx_q0_in,
  input  wire signed [DATA_WIDTH-1:0] rx_i1_in,
  input  wire signed [DATA_WIDTH-1:0] rx_q1_in,
  output reg                          rx_valid_out,
  output reg signed [DATA_WIDTH-1:0]  rx_i0_out,
  output reg signed [DATA_WIDTH-1:0]  rx_q0_out,
  output reg signed [DATA_WIDTH-1:0]  rx_i1_out,
  output reg signed [DATA_WIDTH-1:0]  rx_q1_out,

  input  wire                         tx_valid0_in,
  input  wire                         tx_valid1_in,
  input  wire signed [DATA_WIDTH-1:0] tx_i0_in,
  input  wire signed [DATA_WIDTH-1:0] tx_q0_in,
  input  wire signed [DATA_WIDTH-1:0] tx_i1_in,
  input  wire signed [DATA_WIDTH-1:0] tx_q1_in,
  output reg                          tx_valid0_out,
  output reg                          tx_valid1_out,
  output reg signed [DATA_WIDTH-1:0]  tx_i0_out,
  output reg signed [DATA_WIDTH-1:0]  tx_q0_out,
  output reg signed [DATA_WIDTH-1:0]  tx_i1_out,
  output reg signed [DATA_WIDTH-1:0]  tx_q1_out
);

  localparam integer RX_PAYLOAD_WIDTH = 4*DATA_WIDTH + 2;
  localparam integer TX_PAYLOAD_WIDTH = 4*DATA_WIDTH + 3;
  localparam integer PROD_WIDTH = DATA_WIDTH + COEFF_WIDTH;
  localparam integer MIX_WIDTH = PROD_WIDTH + 1;

  // ------------------------------------------------------------------------
  // Infrequent AXI configuration CDC. The configuration bus has three
  // settling stages; the independently synchronized apply toggle takes four
  // stages before it captures that bus.
  // ------------------------------------------------------------------------

  (* ASYNC_REG = "TRUE" *) reg [PHASE_WIDTH-1:0] cfg_rx_ftw_meta;
  (* ASYNC_REG = "TRUE" *) reg [PHASE_WIDTH-1:0] cfg_rx_ftw_sync1;
  reg [PHASE_WIDTH-1:0] cfg_rx_ftw_sync2;
  (* ASYNC_REG = "TRUE" *) reg [PHASE_WIDTH-1:0] cfg_tx_ftw_meta;
  (* ASYNC_REG = "TRUE" *) reg [PHASE_WIDTH-1:0] cfg_tx_ftw_sync1;
  reg [PHASE_WIDTH-1:0] cfg_tx_ftw_sync2;
  (* ASYNC_REG = "TRUE" *) reg [3:0] cfg_control_meta;
  (* ASYNC_REG = "TRUE" *) reg [3:0] cfg_control_sync1;
  reg [3:0] cfg_control_sync2;
  (* ASYNC_REG = "TRUE" *) reg [3:0] apply_sync;
  reg apply_seen;

  reg signed [PHASE_WIDTH-1:0] rx_ftw_active;
  reg signed [PHASE_WIDTH-1:0] tx_ftw_active;
  reg rx_enable_active;
  reg tx_enable_active;
  reg [PHASE_WIDTH-1:0] rx_phase;
  reg [PHASE_WIDTH-1:0] tx_phase;

  wire apply_pulse = apply_sync[3] ^ apply_seen;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cfg_rx_ftw_meta  <= {PHASE_WIDTH{1'b0}};
      cfg_rx_ftw_sync1 <= {PHASE_WIDTH{1'b0}};
      cfg_rx_ftw_sync2 <= {PHASE_WIDTH{1'b0}};
      cfg_tx_ftw_meta  <= {PHASE_WIDTH{1'b0}};
      cfg_tx_ftw_sync1 <= {PHASE_WIDTH{1'b0}};
      cfg_tx_ftw_sync2 <= {PHASE_WIDTH{1'b0}};
      cfg_control_meta  <= 4'b0000;
      cfg_control_sync1 <= 4'b0000;
      cfg_control_sync2 <= 4'b0000;
      apply_sync <= 4'b0000;
      apply_seen <= 1'b0;
      rx_ftw_active <= {PHASE_WIDTH{1'b0}};
      tx_ftw_active <= {PHASE_WIDTH{1'b0}};
      rx_enable_active <= 1'b0;
      tx_enable_active <= 1'b0;
      rx_phase <= {PHASE_WIDTH{1'b0}};
      tx_phase <= {PHASE_WIDTH{1'b0}};
    end else begin
      cfg_rx_ftw_meta  <= cfg_rx_ftw;
      cfg_rx_ftw_sync1 <= cfg_rx_ftw_meta;
      cfg_rx_ftw_sync2 <= cfg_rx_ftw_sync1;
      cfg_tx_ftw_meta  <= cfg_tx_ftw;
      cfg_tx_ftw_sync1 <= cfg_tx_ftw_meta;
      cfg_tx_ftw_sync2 <= cfg_tx_ftw_sync1;
      cfg_control_meta  <= cfg_control;
      cfg_control_sync1 <= cfg_control_meta;
      cfg_control_sync2 <= cfg_control_sync1;
      apply_sync <= {apply_sync[2:0], cfg_control[2]};

      if (apply_pulse) begin
        apply_seen <= apply_sync[3];
        rx_ftw_active <= $signed(cfg_rx_ftw_sync2);
        tx_ftw_active <= $signed(cfg_tx_ftw_sync2);
        rx_enable_active <= cfg_control_sync2[0];
        tx_enable_active <= cfg_control_sync2[1];
      end

      if (apply_pulse && cfg_control_sync2[3]) begin
        rx_phase <= {PHASE_WIDTH{1'b0}};
        tx_phase <= {PHASE_WIDTH{1'b0}};
      end else begin
        if (rx_valid_in)
          rx_phase <= rx_phase + rx_ftw_active;
        if (tx_valid0_in || tx_valid1_in)
          tx_phase <= tx_phase + tx_ftw_active;
      end
    end
  end

  // ------------------------------------------------------------------------
  // Sine/cosine generation. ADI's pipelined CORDIC transports the input I/Q,
  // valid and bypass state alongside the angle, keeping everything aligned.
  // ------------------------------------------------------------------------

  wire [RX_PAYLOAD_WIDTH-1:0] rx_payload_in = {
    rx_enable_active, rx_valid_in, rx_i1_in, rx_q1_in, rx_i0_in, rx_q0_in
  };
  wire [TX_PAYLOAD_WIDTH-1:0] tx_payload_in = {
    tx_enable_active, tx_valid1_in, tx_valid0_in,
    tx_i1_in, tx_q1_in, tx_i0_in, tx_q0_in
  };
  wire [RX_PAYLOAD_WIDTH-1:0] rx_payload_cordic;
  wire [TX_PAYLOAD_WIDTH-1:0] tx_payload_cordic;
  wire signed [COEFF_WIDTH-1:0] rx_sine;
  wire signed [COEFF_WIDTH-1:0] rx_cosine;
  wire signed [COEFF_WIDTH-1:0] tx_sine;
  wire signed [COEFF_WIDTH-1:0] tx_cosine;
  // ad_dds_sine_cordic registers its angle before the first CORDIC stage,
  // while ddata enters that stage directly. Present the next phase during a
  // valid cycle so the registered angle aligns with the following sample.
  wire [PHASE_WIDTH-1:0] rx_phase_lookahead =
    rx_phase + (rx_valid_in ? rx_ftw_active : {PHASE_WIDTH{1'b0}});
  wire [PHASE_WIDTH-1:0] tx_phase_lookahead =
    tx_phase + ((tx_valid0_in || tx_valid1_in) ? tx_ftw_active :
                                                    {PHASE_WIDTH{1'b0}});

  ad_dds_sine_cordic #(
    .PHASE_DW(CORDIC_PHASE_WIDTH),
    .CORDIC_DW(COEFF_WIDTH),
    .DELAY_DW(RX_PAYLOAD_WIDTH)
  ) rx_cordic (
    .clk(clk),
    .angle(rx_phase_lookahead[PHASE_WIDTH-1 -: CORDIC_PHASE_WIDTH]),
    .sine(rx_sine),
    .cosine(rx_cosine),
    .ddata_in(rx_payload_in),
    .ddata_out(rx_payload_cordic)
  );

  ad_dds_sine_cordic #(
    .PHASE_DW(CORDIC_PHASE_WIDTH),
    .CORDIC_DW(COEFF_WIDTH),
    .DELAY_DW(TX_PAYLOAD_WIDTH)
  ) tx_cordic (
    .clk(clk),
    .angle(tx_phase_lookahead[PHASE_WIDTH-1 -: CORDIC_PHASE_WIDTH]),
    .sine(tx_sine),
    .cosine(tx_cosine),
    .ddata_in(tx_payload_in),
    .ddata_out(tx_payload_cordic)
  );

  wire signed [DATA_WIDTH-1:0] rx_q0_cordic = rx_payload_cordic[DATA_WIDTH-1:0];
  wire signed [DATA_WIDTH-1:0] rx_i0_cordic = rx_payload_cordic[2*DATA_WIDTH-1:DATA_WIDTH];
  wire signed [DATA_WIDTH-1:0] rx_q1_cordic = rx_payload_cordic[3*DATA_WIDTH-1:2*DATA_WIDTH];
  wire signed [DATA_WIDTH-1:0] rx_i1_cordic = rx_payload_cordic[4*DATA_WIDTH-1:3*DATA_WIDTH];
  wire rx_valid_cordic = rx_payload_cordic[4*DATA_WIDTH];
  wire rx_enable_cordic = rx_payload_cordic[4*DATA_WIDTH+1];

  wire signed [DATA_WIDTH-1:0] tx_q0_cordic = tx_payload_cordic[DATA_WIDTH-1:0];
  wire signed [DATA_WIDTH-1:0] tx_i0_cordic = tx_payload_cordic[2*DATA_WIDTH-1:DATA_WIDTH];
  wire signed [DATA_WIDTH-1:0] tx_q1_cordic = tx_payload_cordic[3*DATA_WIDTH-1:2*DATA_WIDTH];
  wire signed [DATA_WIDTH-1:0] tx_i1_cordic = tx_payload_cordic[4*DATA_WIDTH-1:3*DATA_WIDTH];
  wire tx_valid0_cordic = tx_payload_cordic[4*DATA_WIDTH];
  wire tx_valid1_cordic = tx_payload_cordic[4*DATA_WIDTH+1];
  wire tx_enable_cordic = tx_payload_cordic[4*DATA_WIDTH+2];

  // ------------------------------------------------------------------------
  // Complex multipliers. Four real products per complex channel are inferred
  // as DSP48s. Results are scaled from Q1.(COEFF_WIDTH-1) and saturated back
  // to DATA_WIDTH.
  // ------------------------------------------------------------------------

  reg signed [PROD_WIDTH-1:0] rx_i0_cos, rx_q0_sin, rx_i0_sin, rx_q0_cos;
  reg signed [PROD_WIDTH-1:0] rx_i1_cos, rx_q1_sin, rx_i1_sin, rx_q1_cos;
  reg signed [PROD_WIDTH-1:0] tx_i0_cos, tx_q0_sin, tx_i0_sin, tx_q0_cos;
  reg signed [PROD_WIDTH-1:0] tx_i1_cos, tx_q1_sin, tx_i1_sin, tx_q1_cos;
  reg signed [DATA_WIDTH-1:0] rx_i0_delay, rx_q0_delay, rx_i1_delay, rx_q1_delay;
  reg signed [DATA_WIDTH-1:0] tx_i0_delay, tx_q0_delay, tx_i1_delay, tx_q1_delay;
  reg rx_valid_mult, tx_valid0_mult, tx_valid1_mult;
  reg rx_enable_mult, tx_enable_mult;

  wire signed [MIX_WIDTH-1:0] rx_i0_mix =
    $signed({rx_i0_cos[PROD_WIDTH-1], rx_i0_cos}) -
    $signed({rx_q0_sin[PROD_WIDTH-1], rx_q0_sin});
  wire signed [MIX_WIDTH-1:0] rx_q0_mix =
    $signed({rx_i0_sin[PROD_WIDTH-1], rx_i0_sin}) +
    $signed({rx_q0_cos[PROD_WIDTH-1], rx_q0_cos});
  wire signed [MIX_WIDTH-1:0] rx_i1_mix =
    $signed({rx_i1_cos[PROD_WIDTH-1], rx_i1_cos}) -
    $signed({rx_q1_sin[PROD_WIDTH-1], rx_q1_sin});
  wire signed [MIX_WIDTH-1:0] rx_q1_mix =
    $signed({rx_i1_sin[PROD_WIDTH-1], rx_i1_sin}) +
    $signed({rx_q1_cos[PROD_WIDTH-1], rx_q1_cos});
  wire signed [MIX_WIDTH-1:0] tx_i0_mix =
    $signed({tx_i0_cos[PROD_WIDTH-1], tx_i0_cos}) -
    $signed({tx_q0_sin[PROD_WIDTH-1], tx_q0_sin});
  wire signed [MIX_WIDTH-1:0] tx_q0_mix =
    $signed({tx_i0_sin[PROD_WIDTH-1], tx_i0_sin}) +
    $signed({tx_q0_cos[PROD_WIDTH-1], tx_q0_cos});
  wire signed [MIX_WIDTH-1:0] tx_i1_mix =
    $signed({tx_i1_cos[PROD_WIDTH-1], tx_i1_cos}) -
    $signed({tx_q1_sin[PROD_WIDTH-1], tx_q1_sin});
  wire signed [MIX_WIDTH-1:0] tx_q1_mix =
    $signed({tx_i1_sin[PROD_WIDTH-1], tx_i1_sin}) +
    $signed({tx_q1_cos[PROD_WIDTH-1], tx_q1_cos});

  function automatic signed [DATA_WIDTH-1:0] scale_saturate;
    input signed [MIX_WIDTH-1:0] value;
    reg signed [MIX_WIDTH-1:0] rounded;
    reg signed [MIX_WIDTH-1:0] max_sample;
    reg signed [MIX_WIDTH-1:0] min_sample;
    begin
      rounded = value >>> (COEFF_WIDTH-1);
      max_sample = ({{(MIX_WIDTH-1){1'b0}}, 1'b1} << (DATA_WIDTH-1)) - 1'b1;
      min_sample = -({{(MIX_WIDTH-1){1'b0}}, 1'b1} << (DATA_WIDTH-1));
      if (rounded > max_sample)
        scale_saturate = {1'b0, {(DATA_WIDTH-1){1'b1}}};
      else if (rounded < min_sample)
        scale_saturate = {1'b1, {(DATA_WIDTH-1){1'b0}}};
      else
        scale_saturate = rounded[DATA_WIDTH-1:0];
    end
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_i0_cos <= 0; rx_q0_sin <= 0; rx_i0_sin <= 0; rx_q0_cos <= 0;
      rx_i1_cos <= 0; rx_q1_sin <= 0; rx_i1_sin <= 0; rx_q1_cos <= 0;
      tx_i0_cos <= 0; tx_q0_sin <= 0; tx_i0_sin <= 0; tx_q0_cos <= 0;
      tx_i1_cos <= 0; tx_q1_sin <= 0; tx_i1_sin <= 0; tx_q1_cos <= 0;
      rx_i0_delay <= 0; rx_q0_delay <= 0; rx_i1_delay <= 0; rx_q1_delay <= 0;
      tx_i0_delay <= 0; tx_q0_delay <= 0; tx_i1_delay <= 0; tx_q1_delay <= 0;
      rx_valid_mult <= 1'b0;
      tx_valid0_mult <= 1'b0;
      tx_valid1_mult <= 1'b0;
      rx_enable_mult <= 1'b0;
      tx_enable_mult <= 1'b0;
      rx_valid_out <= 1'b0;
      tx_valid0_out <= 1'b0;
      tx_valid1_out <= 1'b0;
      rx_i0_out <= 0; rx_q0_out <= 0; rx_i1_out <= 0; rx_q1_out <= 0;
      tx_i0_out <= 0; tx_q0_out <= 0; tx_i1_out <= 0; tx_q1_out <= 0;
    end else begin
      rx_i0_cos <= $signed(rx_i0_cordic) * $signed(rx_cosine);
      rx_q0_sin <= $signed(rx_q0_cordic) * $signed(rx_sine);
      rx_i0_sin <= $signed(rx_i0_cordic) * $signed(rx_sine);
      rx_q0_cos <= $signed(rx_q0_cordic) * $signed(rx_cosine);
      rx_i1_cos <= $signed(rx_i1_cordic) * $signed(rx_cosine);
      rx_q1_sin <= $signed(rx_q1_cordic) * $signed(rx_sine);
      rx_i1_sin <= $signed(rx_i1_cordic) * $signed(rx_sine);
      rx_q1_cos <= $signed(rx_q1_cordic) * $signed(rx_cosine);
      tx_i0_cos <= $signed(tx_i0_cordic) * $signed(tx_cosine);
      tx_q0_sin <= $signed(tx_q0_cordic) * $signed(tx_sine);
      tx_i0_sin <= $signed(tx_i0_cordic) * $signed(tx_sine);
      tx_q0_cos <= $signed(tx_q0_cordic) * $signed(tx_cosine);
      tx_i1_cos <= $signed(tx_i1_cordic) * $signed(tx_cosine);
      tx_q1_sin <= $signed(tx_q1_cordic) * $signed(tx_sine);
      tx_i1_sin <= $signed(tx_i1_cordic) * $signed(tx_sine);
      tx_q1_cos <= $signed(tx_q1_cordic) * $signed(tx_cosine);

      rx_i0_delay <= rx_i0_cordic; rx_q0_delay <= rx_q0_cordic;
      rx_i1_delay <= rx_i1_cordic; rx_q1_delay <= rx_q1_cordic;
      tx_i0_delay <= tx_i0_cordic; tx_q0_delay <= tx_q0_cordic;
      tx_i1_delay <= tx_i1_cordic; tx_q1_delay <= tx_q1_cordic;
      rx_valid_mult <= rx_valid_cordic;
      tx_valid0_mult <= tx_valid0_cordic;
      tx_valid1_mult <= tx_valid1_cordic;
      rx_enable_mult <= rx_enable_cordic;
      tx_enable_mult <= tx_enable_cordic;

      rx_valid_out <= rx_valid_mult;
      tx_valid0_out <= tx_valid0_mult;
      tx_valid1_out <= tx_valid1_mult;
      if (rx_valid_mult) begin
        rx_i0_out <= rx_enable_mult ? scale_saturate(rx_i0_mix) : rx_i0_delay;
        rx_q0_out <= rx_enable_mult ? scale_saturate(rx_q0_mix) : rx_q0_delay;
        rx_i1_out <= rx_enable_mult ? scale_saturate(rx_i1_mix) : rx_i1_delay;
        rx_q1_out <= rx_enable_mult ? scale_saturate(rx_q1_mix) : rx_q1_delay;
      end
      if (tx_valid0_mult) begin
        tx_i0_out <= tx_enable_mult ? scale_saturate(tx_i0_mix) : tx_i0_delay;
        tx_q0_out <= tx_enable_mult ? scale_saturate(tx_q0_mix) : tx_q0_delay;
      end
      if (tx_valid1_mult) begin
        tx_i1_out <= tx_enable_mult ? scale_saturate(tx_i1_mix) : tx_i1_delay;
        tx_q1_out <= tx_enable_mult ? scale_saturate(tx_q1_mix) : tx_q1_delay;
      end
    end
  end

endmodule
