// CS12 sync-frame inserter (post-mux, CS12-only).
//
// Every SYNC_PERIOD_SAMPLES IQ samples, ONE CS12 burst is replaced by a sync burst:
// 6 cycles whose 24 emitted stream bytes are a fixed 160-bit MAGIC + a 32-bit
// free-running COUNTER, instead of packed IQ. This makes the CS12 byte stream
// self-framing: the host finds byte alignment deterministically, re-syncs instantly
// after an overflow/dropped block, and uses COUNTER as a heartbeat. Real bursts before
// and after are unshifted (we substitute one burst, we don't insert/delay).
//
// CS12-only: in CS8 (2'b10) / CS16 (2'b11) the data passes through unchanged, so the
// shared DMA and the standard clients are completely unaffected.
//
// Stream byte contract (LE 16-bit words, cpack emits data_out0 then data_out1 per cycle):
//   A1 5C 1E AB D2 C5 EF 12 37 9A 4D 6B E1 F0 8A 3C 56 7D 91 24  <CTR0 CTR1 CTR2 CTR3>
//   bytes 0..19 = MAGIC (fixed) ; bytes 20..23 = COUNTER uint32 LE, +1 per sync burst.
// The per-cycle word values below are chosen so the LE byte interleave equals that stream.
// The 8 replaced samples are lost (the stream has a gap). Full host contract, including the
// burst layout and loss detection: projects/tezuka/doc/cs12-stream.md.
module cs12_sync_frame #(
    parameter integer SYNC_PERIOD_SAMPLES = 262144,   // multiple of 8; hosts measure it from the MAGIC spacing
    parameter integer DATA_WIDTH          = 16
)(
    input                       clk,
    input                       rst_n,
    input                       Enable0,    // mux mode selects (wire to the same dout_enable_*)
    input                       Enable1,    // CS12 == {Enable0,Enable1}==2'b01
    input                       frame_start,// mux: pulses at burst word-0 (out_count==0)
    input                       valid_in,   // mux: valid_out
    input  [DATA_WIDTH-1:0]     data_in0,   // mux: data_out0 (I word)
    input  [DATA_WIDTH-1:0]     data_in1,   // mux: data_out1 (Q word)
    output reg [DATA_WIDTH-1:0] data_out0,
    output reg [DATA_WIDTH-1:0] data_out1
);
    localparam integer BURSTS_PER_PERIOD = SYNC_PERIOD_SAMPLES / 8;
    localparam integer BCW = (BURSTS_PER_PERIOD <= 1) ? 1 : $clog2(BURSTS_PER_PERIOD);

    wire cs12_mode = ~Enable0 & Enable1;

    reg [BCW-1:0] burst_count;
    reg [2:0]     cyc;            // burst cycle 0..5
    reg           sync_latch;     // held across the sync burst's 6 cycles
    reg [31:0]    counter;

    wire at_sync  = cs12_mode & frame_start & (burst_count == BURSTS_PER_PERIOD-1);
    wire sync_now = at_sync | (sync_latch & ~frame_start);
    wire [2:0] cur = frame_start ? 3'd0 : cyc;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            burst_count <= 0; cyc <= 0; sync_latch <= 1'b0; counter <= 32'd0;
        end else begin
            if (!cs12_mode) begin
                burst_count <= 0; sync_latch <= 1'b0;
            end else if (frame_start) begin
                burst_count <= at_sync ? {BCW{1'b0}} : burst_count + 1'b1;
                sync_latch  <= at_sync;
                if (at_sync) counter <= counter + 32'd1;
            end
            if (frame_start)                  cyc <= 3'd1;
            else if (valid_in && cyc != 3'd5) cyc <= cyc + 1'b1;
        end
    end

    always @(*) begin
        if (sync_now) begin
            case (cur)
                3'd0: begin data_out0 = 16'h5CA1; data_out1 = 16'hAB1E; end
                3'd1: begin data_out0 = 16'hC5D2; data_out1 = 16'h12EF; end
                3'd2: begin data_out0 = 16'h9A37; data_out1 = 16'h6B4D; end
                3'd3: begin data_out0 = 16'hF0E1; data_out1 = 16'h3C8A; end
                3'd4: begin data_out0 = 16'h7D56; data_out1 = 16'h2491; end
                3'd5: begin data_out0 = counter[15:0]; data_out1 = counter[31:16]; end
                default: begin data_out0 = data_in0; data_out1 = data_in1; end
            endcase
        end else begin
            data_out0 = data_in0;
            data_out1 = data_in1;
        end
    end
endmodule
