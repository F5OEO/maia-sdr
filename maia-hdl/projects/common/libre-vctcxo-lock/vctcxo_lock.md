# vctcxo_lock register map

32-bit AXI-Lite, 11 implemented word-registers at offsets `0x00`-`0x28`. Base address
`0x43C00000` on the `libre` board (`ad_cpu_interconnect` call in
`boards/libre/vcxo_ctrl.tcl`).

This IP replaces `projects/common/antsdr-hdl/axi_vcxo_ctrl` on the
`libre` board only - `axi_vcxo_ctrl` is untouched and still used
elsewhere. It preserves the original board-facing ports and base address and
adds internal NCO-control outputs for the Libre block design. It has a
different internal architecture - see "Why a different architecture"
below before assuming any behavior carries over from the old register
map (`axi_vcxo_ctrl/vcxodac.md`).

| Offset | Name | R/W | Bits | Meaning |
|---|---|---|---|---|
| `0x00` | reg0 (control) | R/W | `[0]` | `dac_mode`: 0 = loop-controlled DAC value (normal), 1 = force `dac_user_set_value` (manual/test) |
| | | | `[1]` | `dac_dither_dis`: 0 = dither enabled (default), 1 = disabled, plain truncation. Only meaningful for `DEVICE=DAC5311/DAC6311` (DAC7311 already gets the full 12-bit correction range). |
| | | | `[9:2]` | `p_shift` - proportional gain, centered at `128` = unity. Above 128 amplifies (left-shift), below attenuates (right-shift). Default `124` - see "Tuning p_shift/i_shift" below for the derivation (rescaled from the `ocpi.osp.libresdr` reference's `p_shift=4`, then empirically attenuated 4 bits further for this board's specific DAC7311/VCTCXO sensitivity). |
| | | | `[17:10]` | `i_shift` - integral gain, same centered-at-128 convention. Default `124` - re-tuned (see "Tuning p_shift/i_shift" below) after the sign fix and 1s measurement window; the earlier `108` derived alongside `p_shift` above turned out inert once the loop actually closed. |
| | | | `[31:18]` | unused |
| `0x04` | reg1 (manual setpoint / center) | R/W | `[15:0]` | `dac_user_set_value` - DAC code sent when `dac_mode=1` |
| | | | `[31:16]` | `center_dac` - DAC value the loop corrects around, and what it holds at when frozen (see "Freeze behavior" below). Default `0x2800` (10240) - **not** the `ocpi.osp.libresdr` reference's naive mid-scale default (`center_dac=2048` i.e. `0x8000` truncated for `DEVICE=DAC7311`). An earlier version of this port matched that reference default exactly; an open-loop DAC sweep on this board (see "The sign bug and the center_dac dead zone" below) found `0x8000` sits in a flat/saturated region of this specific VCTCXO's actual pulling curve, while `0x2800` - matching the value the earlier `b205_ref_pll.v` design had empirically swept to, for a different measurement architecture - is right where `freq_error` crosses zero. Re-sweep via `dac_mode=1`/`dac_user_set_value` if it doesn't converge cleanly on different hardware. |
| `0x08` | live DAC value | RO | `[15:0]` | The actual 16-bit setpoint currently driving the DAC (loop output or forced value) |
| `0x0C` | reg3 (ref select) | R/W | `[1:0]` | `dac_ref_sel`: `00`=CLKIN_10MHz, `01`=PPS_IN, `10`=PPS_GPS, `11`=none. Unlike the old design, this directly determines the measurement mode too (`00`->10 MHz counting, `01`/`10`->1PPS counting) - there's no auto-classification of what the selected signal looks like. **Default `00`** (auto-starts the loop on boot) - a deliberate, confirmed departure from the `ocpi.osp.libresdr` reference, which defaults `ref_source` to `none` (loop frozen until software explicitly enables it). This project has defaulted to auto-start since the original `b205_ref_pll.v` design and that convention was kept on purpose, unlike `p_shift`/`i_shift`/`center_dac` above, which are genuine numeric-fidelity fixes. |
| `0x10` | status | RO | `[0]` | `locked`: `ref_present` and the most recent measurement window's `|freq_error| <= lock_thresh`. Continuously re-evaluated against the latest completed window (1s period for the 10 MHz path - see "Measurement window" below), not a multi-window shift-register history like the old `ld`. |
| | | `[1]` | `ref_present`: reference edges are arriving (debounced by a saturating timeout counter, not reactive to a single missed edge). |
| | | `[31:2]` | unused |
| `0x14` | reg5 (lock threshold) | R/W | `[31:0]` | `lock_thresh` - compared against `|freq_error|` (raw edge-count units, see below) for the `locked` bit. Default `100`. **Untested starting point.** |
| `0x18` | live frequency error | RO | `[31:0]` | `freq_error` - signed, the most recent completed measurement window's edge-count error (`measured - expected`; negative = XO slow, positive = fast). Direct diagnostic readout - no bit-decoding needed, unlike the old design's status word. |
| `0x1C` | reserved | - | - | unused |
| `0x20` | RX NCO FTW | R/W | `[31:0]` | Signed Q0.32 phase increment in turns per valid RX sample. This is a shadow value until `apply_toggle` changes. Default `0` (bypass). |
| `0x24` | TX NCO FTW | R/W | `[31:0]` | Signed Q0.32 phase increment in turns per valid TX sample. This is a shadow value until `apply_toggle` changes. Default `0` (bypass). |
| `0x28` | NCO control | R/W | `[0]` | `rx_enable`: 1 enables digital RX rotation; 0 selects the exact latency-matched bypass. Default 0. |
| | | | `[1]` | `tx_enable`: 1 enables digital TX rotation; 0 selects the exact latency-matched bypass. Default 0. |
| | | | `[2]` | `apply_toggle`: software inverts this bit after writing both FTWs and the enable bits. The sample-clock domain then captures the complete configuration atomically. |
| | | | `[3]` | `phase_reset`: when set during an apply event, reset both phase accumulators. Clear it for phase-continuous later updates. |
| | | | `[31:4]` | unused |

## Digital correction for a fixed TCXO

Some LibreSDR variants populate an oscillator whose tune pin does not change
its frequency. For those boards the DAC loop cannot close, but `freq_meas`
still provides an accurate error relative to the selected 10 MHz/PPS input.
The Libre block design therefore contains a complex RX/TX NCO after the ADC
FIFO and before the DAC FIFO. It is disabled by default and is not present in
the other board projects.

Use an explicit firmware setting to select this mode; do not infer a fixed
TCXO merely from `locked=0`, because a missing reference produces the same
status. The intended modes are:

| Board/mode | DAC | Digital NCO |
|---|---|---|
| Working VCTCXO | `dac_mode=0` (PI loop) | RX/TX disabled |
| Fixed TCXO | `dac_mode=1` (fixed safe code) | RX/TX enabled |
| No reference | hold existing setting | hold the last valid FTWs |

Keep the AD936x `xo_correction` at its nominal `40000000`; changing it is not
part of this mode. With the current one-second measurement window:

```text
actual_xo_hz = 40,000,000 + freq_error
rf_error_hz  = requested_rf_hz * freq_error / 40,000,000
actual_fs_hz = requested_fs_hz * actual_xo_hz / 40,000,000
```

Here `requested_fs_hz` is the AD936x converter sample rate at the correction
point: the ADC rate before Maia/host decimation for RX, and the final DAC rate
after optional TX interpolation. Do not use the lower host-visible decimated
rate in the FTW calculation.

`iq_xo_corrector` defines a positive FTW as multiplication by a positive
complex rotation (`exp(+j*phase)`). Under the normal AD936x I/Q convention the
software words are therefore:

```text
rx_ftw = round( rf_error_hz * 2^32 / actual_fs_hz)
tx_ftw = round(-rf_error_hz * 2^32 / actual_fs_hz)
```

For example, `freq_error=-133`, RF=2.5 GHz and Fs=2 MSPS gives an RF error of
`-8312.5 Hz`, `actual_fs_hz=1999993.35`, `rx_ftw=-17851017`
(`0xFEEF9D77`) and `tx_ftw=17851017` (`0x01106289`). RX therefore rotates
down by 8312.5 Hz and TX rotates up by 8312.5 Hz.
Verify the final RX/TX sign once on hardware because an I/Q swap elsewhere in
the board path reverses the convention.

Write `0x20` and `0x24` first. Then preserve the enable bits and invert bit 2
of `0x28`; this apply-toggle ordering is required by the clock-domain crossing.
Set bit 3 for the first enable and clear it for later drift updates if phase
continuity is desired. The NCO changes spectral position only: the small ppm
error in the physical sample rate remains unchanged.

## Why a different architecture

The earlier antsdr-hdl-derived design (`b205_ref_pll.v`) measured the
VCTCXO's frequency using a sample clock that was itself `PLLE2_ADV`-
derived from the VCTCXO's own output - the measurement and the thing
being measured shared noise. That single decision was the root cause of
a long chain of bugs, found and fixed one at a time over an extended
debugging session: a chicken-and-egg bootstrap deadlock (the loop
couldn't validate the reference because its own clock was wrong,
because the loop hadn't corrected it yet), a long-window statistical
gate whose tolerance had to be loosened by >10x past its originally
intended value once the measurement's own noise floor was understood,
and a lock-detection threshold that could never sustain because it was
set below what the shared-clock measurement could actually resolve.

This IP is modeled on `ocpi.osp.libresdr`'s `vctcxo_lock.vhd`
(`ref-clk-support-2` branch, ported to Verilog), which avoids the whole
problem class structurally: `freq_meas.v` counts VCTCXO edges using
`s00_axi_aclk` - the Zynq PS's AXI clock (100 MHz on this board,
`sys_ps7/M_AXI_GP0_ACLK`, confirmed independent of the RF/VCTCXO clock
chain) - as the timebase, not a clock derived from the VCTCXO. There is
no PLL in this IP at all; `CLK_40MHz_FPGA` is brought in as a plain
2-FF-synchronized async input, exactly like the reference input pins.

This also gives a large precision improvement essentially for free:
counting VCTCXO edges directly, vs. the old architecture's
~1-part-in-20 single-period measurement that needed heavy statistical
averaging (and inherited shared-clock noise while doing it) to get
anywhere near useful precision.

### Measurement window

`freq_meas.v`'s `MEAS_CYCLES` parameter sets the 10 MHz path's window
length, and directly sets the measurement's quantization floor: each
`freq_error` count represents `1 / (CLK_HZ/10MHz * MEAS_CYCLES)` of the
VCTCXO's nominal frequency. This port originally instantiated
`MEAS_CYCLES=1_000_000` (a straight, faithful-port default) - a 100ms
window with only 4,000,000 expected edges, i.e. ~0.25 ppm/count. That's
coarse enough that the loop could report `locked` and hold a rock-steady
`dac_value` while still being 10-25 ppm off in reality (confirmed
against an external GSM `kalibrate` reading and SDR reception, both
before the sign fix below - see git history), simply because the
measurement couldn't see error below its own ~0.25 ppm quantization
step to begin with. Now instantiated at `MEAS_CYCLES=10_000_000` (a 1s
window, `EXP_10MHZ=40,000,000`), giving 0.025 ppm/count - the same
resolution as the PPS path - at the cost of a 10x slower correction
rate (once/second instead of once/100ms; acceptable, since this loop is
already tuned to be gentle over many windows regardless).

## Control law: PI instead of proportional + ad-hoc dead-band

The old design used a bare proportional term with a manually-tuned
dead-band to suppress small-signal chatter - a dead-band with no
hysteresis turned out to produce its own limit-cycle bounce whose
amplitude tracked the dead-band threshold directly, found by sweeping
`deadband_cycles` from 5 to 2000 and fast-polling the live DAC value.

`pi_ctrl.v` is a real PI controller (proportional + integral, both with
independently configurable gain) with hard output saturation and
conditional-integration anti-windup (a deliberate addition beyond the
`ocpi.osp.libresdr` reference - see the comment in `pi_ctrl.v`). No
dead-band is used or needed; integral control drives steady-state error
toward zero without needing a threshold to stop correcting.

`pi_ctrl.v` is a small multi-cycle pipeline (7 clk cycles from `valid`
to `valid_out`), not a single combinational cycle. The first version
computed the whole datapath - two 48-bit variable-shift barrel shifters,
several 48-bit adds, the anti-windup comparison, and saturation - all
combinationally in one clock edge. Real timing analysis found a failing
setup path (37 logic levels, ~12.4ns) from `i_acc_reg` through this
logic against the 10ns (100MHz) `s00_axi_aclk` period. There was no
reason to have optimized for single-cycle latency in the first place -
a new result is only needed once per completed measurement window (1s
= 100,000,000 clk cycles for the 10 MHz path, see "Measurement window"
above) - so the fix was to
spread the same arithmetic across a handful of pipeline stages, each
with a full clock period to settle, instead of hand-tuning logic depth.
`valid`/`valid_out` are still a single-cycle pulse interface at the
module boundary; only the internal latency changed.

## Freeze behavior (reference loss)

The old design forced `daco` back to a coarse bootstrap default the
instant the reference was judged lost, producing a real, physically
observable frequency glitch every single time - confirmed on hardware by
toggling the 10 MHz source off and back on and watching the live DAC
value jump.

This design instead **freezes** (holds the last correction, does not
reset to `center_dac`) whenever `dac_ref_sel` selects "none" or
`ref_present` goes low. Since `freq_meas.v` only produces a new
`error_valid` pulse once a full measurement window completes - which
requires the reference to still be present - a genuine reference loss
simply stops new corrections from arriving; the DAC output holds at
whatever it last was, rather than snapping to `center_dac`.

## Tuning `p_shift`/`i_shift`/`lock_thresh`

Defaults are chosen to match the `ocpi.osp.libresdr` reference's own
validated values (from `vctcxo_lock-hdl.xml`/`vctcxo_lock.rst`, fetched
after the first version of this port shipped with untested guesses -
see "the toggling-frequency incident" below): `p_shift=4`, `i_shift=20`,
`lock_thresh=100`, `center_dac=2048`. `lock_thresh` and `center_dac`
(see above) carry over directly, since they're in units (edge counts,
DAC-code mid-scale) that don't depend on this port's internal width
choices. `p_shift`/`i_shift` need rescaling first - see below - because
the reference's `pi_ctrl` is instantiated at `OUTPUT_W=12` (matching
DAC7311 exactly, no dither headroom), while this port keeps `OUTPUT_W=16`
to preserve dithering across DAC5311/DAC6311/DAC7311 (see "Dither"
below). 16 vs. 12 bits is a 4-bit/16x difference in what a given raw
correction number physically means, so reproducing the reference's
*actual* gain - not just copying its raw shift amounts - requires
subtracting 4 from each of their attenuation amounts before converting
to this port's centered-at-`SHIFT_MID` field encoding:

```
p_shift field = SHIFT_MID - (4  - 4) = 128 - 0  = 128  (unity)
i_shift field = SHIFT_MID - (20 - 4) = 128 - 16 = 112
```

**The toggling-frequency incident, in two parts:**

1. The first version of this port defaulted both `p_shift` and `i_shift`
   to `128` (unity, i.e. no rescaling applied at all) without the
   derivation above. `i_shift=128` gave the integrator essentially zero
   attenuation, against the reference's heavily-damped `1/2^20` - on
   real hardware this produced the correction saturating and swinging
   between extremes on nearly every measurement window, visible on a
   spectrum analyzer as two sharp, static peaks (a clean bang-bang
   toggle) rather than the loop converging.

2. After applying the rescaled values above (`p_shift=128`,
   `i_shift=112`) the *same* two-peak toggling persisted. Confirmed live
   (register write, no rebuild) that this board's specific DAC7311/
   VCTCXO pairing needs 4 more bits of attenuation than even the
   correctly-rescaled match to the reference's own gain: `p_shift=124`
   alone gave a fully static `dac_value` (90/90 one-second samples, no
   movement at all); shifting `i_shift` by the same 4 bits (`108`) to
   preserve the reference's relative P/I balance was equally stable.
   This mirrors a finding from the earlier `b205_ref_pll.v` design on
   this same hardware, which also needed markedly gentler correction
   than theory (there, the antsdr-hdl reference design's own
   assumptions) predicted. **This turned out to be a red herring** - see
   "The sign bug and the center_dac dead zone" below: `p_shift=124`/
   `i_shift=108` looking "stable" here was really the integrator being
   inert under a sign bug, not correct convergence.

3. After the sign fix and `center_dac` correction (see below) and
   widening the measurement window to 1s (see "Measurement window"
   above), `p_shift=124`/`i_shift=108` was re-tested and found genuinely
   inert this time too - at the 1s window rate, `i_shift=108`'s
   `1/2^20`-equivalent attenuation needs on the order of tens of minutes
   to move the DAC by one code. Jumping straight to `i_shift=128` (full
   unity - a 256x gain increase from `120`, not the small step it looks
   like) caused a genuine accumulator runaway: `dac_value` jumped ~33,000
   codes into a saturated region in a single window, `freq_error` pinned
   at a large value, `locked` dropped, and the board needed a reboot to
   recover (the accumulator was stuck saturated with `error`'s sign
   matching its own, so anti-windup's sign-flip snap never triggered -
   error was flat in that saturated DAC region, so it never got the
   chance to flip). Stepping more carefully, `i_shift=124` (one step
   down from the runaway value, not `128`) converges cleanly: from a
   fresh boot, `freq_error` walks from around -27 counts to within a few
   counts of 0 over about 2 minutes, no overshoot, `dac_value` ramp
   smooth throughout. **Current defaults: `p_shift=124`, `i_shift=124`.**
   If retuning `i_shift` again, step gradually (a few field values at a
   time) rather than jumping to unity - the gain difference across the
   field's range is exponential, not linear, and a step that looks small
   in field-value terms can be a large multiple in actual gain.

If you ever see that same two-peak signature again after changing
`p_shift`/`i_shift`, suspect the gain being too aggressive first -
specifically the integral term, since a bare proportional error that's
merely a bit too strong tends to overshoot and ring, while an
under-damped integrator tends to produce this cleaner, more sustained
bang-bang toggle. If instead you see a large, sudden jump followed by a
frozen `dac_value` and `locked` dropping, suspect accumulator runaway
(item 3 above) - recover with a reboot, not more register writes, since
a saturated accumulator in a flat DAC region won't self-correct.

## Absolute accuracy is bounded by the external reference, not this loop

Once the sign bug, `center_dac` dead zone, and measurement window were
all fixed, `freq_error` converges to within a fraction of a ppm of
`CLKIN_10MHz` and holds there (modulo real environmental/thermal drift
the loop continues to track). Despite that, external verification (GSM
`kalibrate`, using this same board as the receiver) kept reading a
roughly constant ~2.5-2.8 ppm offset throughout - essentially unchanged
across a >5x improvement in the loop's own internal convergence. That
invariance is the signature of an error source outside the loop
entirely: the loop can only be as accurate as the reference it's given.
In this case `CLKIN_10MHz` was fed from a bench signal generator (R&S
SME03) whose standard (non-OCXO) internal reference is typically spec'd
around ~1 ppm, worse with aging/calibration drift - fully consistent
with the observed residual. The LibreSDR's VCTCXO itself is spec'd at
0.5 ppm free-running accuracy (see the board datasheet), which is
*tighter* than a mediocre external reference - disciplining to a worse
reference than the VCTCXO's own factory trim makes real-world accuracy
worse, not better. Before chasing further loop precision, verify
whatever is driving `CLKIN_10MHz` (or `PPS_IN`/`PPS_GPS`) is actually
more accurate than 0.5 ppm; if it isn't, leaving `dac_ref_sel=11` (none,
loop frozen/VCTCXO free-running) may outperform disciplining to it.

Approximate ppm-per-count, for context when picking `lock_thresh` (see
"Measurement window" above for the 10 MHz path's history - this used to
be 10x coarser than the PPS path, no longer):
- 10 MHz path (`dac_ref_sel=00`): 1 count ≈ 0.025 ppm (`error_out` is
  edges over a `CLK_HZ/10MHz * MEAS_CYCLES` = 40,000,000-edge nominal
  window)
- PPS path (`dac_ref_sel=01` or `10`): 1 count ≈ 0.025 ppm (nominal
  window is `CLK_HZ` = 40,000,000 edges) - same resolution as the 10 MHz
  path now.

Expect to need the same empirical, fast-poll-based tuning pass that
`gain_shift`/`deadband_cycles` went through in the old design - see that
history in `axi_vcxo_ctrl/vcxodac.md` for the methodology (poll `0x18`/
`0x08` in a tight loop with no `sleep`, over tens of seconds to minutes,
not a quick glance - a short poll gave a misleadingly clean result more
than once during that process).

Read-modify-write example (libre board base `0x43C00000`, set
`p_shift` to amplify by `<<<2` from unity, preserving other reg0
fields):
```
devmem2 0x43C00000 w $(( ($(devmem2 0x43C00000 w | tail -1) & ~(0xFF << 2)) | (130 << 2) ))
```

## The sign bug and the center_dac dead zone

After the toggling incident above was fixed (gains attenuated) and
`center_dac` was changed to match the reference's naive mid-scale
(`0x8000`), the loop reported `locked=1` with a small, rock-steady
`freq_error` - but external verification (GSM `kalibrate`, SDR
reception at a known frequency) showed real errors of 10-25 ppm, far
outside what the loop believed. Diagnosis, in order:

1. **The integrator was inert, not converged.** At `i_shift=108`
   (`1/2^20` net attenuation given the `OUTPUT_W` rescaling), the
   accumulator needed on the order of 25,000 windows (~42 minutes at
   the old 100ms window) to move the DAC by even one code. A
   short/moderate fast-poll test correctly showed "no oscillation" but
   was mistaken for "converged" - it was actually just too slow to see
   any movement at all. Raising `i_shift` (e.g. to `120`) made the
   integrator visibly active again (`dac_value` ramping monotonically).

2. **`center_dac=0x8000` sits in a flat/saturated region of this
   board's actual VCTCXO pulling curve.** With the integrator now
   visibly ramping, `freq_error` still wasn't shrinking despite
   hundreds of DAC codes of movement. An open-loop sweep (`dac_mode=1`,
   PI controller output disconnected from the DAC entirely, so no loop
   dynamics or sign convention could confound the result) stepped
   `dac_user_set_value` from `0x1000` to `0x9100` and read `freq_error`
   at each point. Result: `freq_error` is flat/insensitive to `dac`
   above roughly `0x7000` (e.g. `0x8300` and `0x9100` - a huge span -
   both read the same error), but clearly monotonic and sensitive
   between `0x1000` and `0x4000`, crossing zero almost exactly at
   `0x2800`. This matches the value `b205_ref_pll.v` had empirically
   swept to on this same board, for what had looked like unrelated
   reasons at the time.

3. **The sign of `correction` relative to `center_dac` was backwards
   for this board.** The same open-loop sweep is unambiguous ground
   truth for the sign of `dErr/dDac`: it's *positive* on this hardware
   (`freq_error` increases as `dac` increases) across the whole usable
   range. `pi_ctrl.v` computes `correction` with the same sign as
   `error_in` (a faithful port of the reference, which assumes the
   opposite polarity on its own hardware), and `vctcxo_lock_v1_0.v` was
   computing `dac_raw = center_dac + correction` - positive feedback
   given this board's actual polarity, not negative feedback. This is
   consistent with everything observed: it explains the original
   two-peak toggling as a classic positive-feedback-plus-saturation
   limit cycle rather than ordinary overshoot, and it explains a
   closed-loop capture (post item 1's fix, pre this fix) where
   `dac_value` walked steadily *away* from the known-good `0x2800`
   zero-crossing while `freq_error` stayed pinned instead of shrinking.
   **Fixed** by flipping the sign at the board-integration boundary -
   `dac_raw = center_dac - correction` in `vctcxo_lock_v1_0.v`, not
   inside `pi_ctrl.v` (whose anti-windup logic keys off the sign of the
   accumulator vs. error internally; the polarity flip belongs where
   the board-specific fact lives, not inside the faithfully-ported
   control law).

`center_dac` was reverted to `0x2800` as part of the same fix (see the
register table above). Confirmed on hardware after rebuild: fresh boot
converges to `freq_error` within a few counts of zero and holds it
there indefinitely, with `dac_value` static (not drifting in either
direction) - the signature of genuine negative-feedback convergence,
not a saturated dead zone or positive-feedback runaway. `p_shift`/
`i_shift` were characterized (steps 1-2 above) before this sign fix, in
the `0x8000` dead zone - they are unvalidated again and were only kept
as a conservative (non-oscillating) starting point; re-tune against the
now-closed loop if the correction rate needs to be faster than what
`i_shift=108`/1s windows give.

## Dither

Same design as the old `b205_ref_pll.v`: below the DAC's native
resolution (8/10/12 bits for DAC5311/DAC6311/DAC7311), a first-order
delta-sigma accumulator toggles the transmitted code between two
adjacent DAC codes with a duty cycle proportional to the discarded
fraction. The dither tick rate is now ~24.4 kHz (100 MHz `clk` / 4096)
instead of the old design's ~48.8 kHz (200 MHz / 4096) - still well
above typical tune-line RC filter corner frequencies, but worth knowing
if retuning the divider ever comes up.

## DAC SPI driver

`dacxx11_spi.v` is a self-contained copy of the already-fixed
DAC5311/DAC6311/DAC7311 driver from
`projects/common/antsdr-hdl/axi_vcxo_ctrl/src/dacxx11_spi.v` (the 16-bit
SPI frame width bug found and fixed earlier this project - `{mode, data,
2'b00}`, not a bare `{mode, data}` that silently zero-extends on the
wrong side). Kept as an independent copy per this IP living outside
`antsdr-hdl`, not a reference to that directory.
