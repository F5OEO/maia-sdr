`timescale 1ns/100ps

// Fastlock profile sweeper: steps a 3-bit profile counter on each rising edge
// of step_in (maia_sdr spectrometer end_fft) and drives it on CTRL_IN1..3.
//
// clk is the maia_sdr clock (the domain of end_fft and of fastlock_profile_in),
// so step_in is a plain synchronous signal and profile_o needs no CDC.
// reset may come from any domain; it is synchronised here.
module sweeper_it (
    input  clk,               // maia_sdr clock
    input  reset,             // asynchronous, active-high
    input  step_in,           // maia_sdr clk_fastlock_out (end_fft)
    output reg  [63:0] gpio_o,   // only bits 11:9 (CTRL_IN1..3) are ever set
    output reg  [2:0] profile_o  // profile of the spectrum just finished
);

    (* ASYNC_REG = "TRUE" *) reg [1:0] reset_sync;
    reg       step_q;
    reg [2:0] count;

    wire rst = reset_sync[1];

    always @(posedge clk or posedge reset) begin
        if (reset)
            reset_sync <= 2'b11;
        else
            reset_sync <= {reset_sync[0], 1'b0};
    end

    always @(posedge clk) begin
        if (rst) begin
            step_q <= 1'b0;
            count <= 3'd0;
            gpio_o <= 64'd0;
            profile_o <= 3'd0;
        end else begin
            step_q <= step_in;
            if (step_in && !step_q) begin
                count <= count + 3'd1;
                // Explicit 3-bit field: (count + 1) << 9 would be evaluated
                // at 64 bits and set bit 12 (EN_AGC) when count == 7.
                gpio_o <= {52'd0, count + 3'd1, 9'd0};
                profile_o <= count;
            end
        end
    end

endmodule

// https://ez.analog.com/rf/wide-band-rf-transceivers/design-support/w/documents/10057/ad936x-documentation-changes
// CTRK_IN1 to CLK_IN3 is used : meaning <<9 instead of 8
