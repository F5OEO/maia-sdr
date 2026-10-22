#!/usr/bin/env python3
"""Real-signal check of the I/Q waterfall and raw capture over a cable.

The transmit board (original Pluto, default 192.168.2.1) sends CW tones,
a noise reference and CP-OFDM through a cable with an attenuator into RX of
the board under test (default Pluto+ 192.168.3.1). For every signal the
magnitude waterfall, the I/Q waterfall and the raw capture are read.
Radio settings of both boards are restored at the end.

Checks: the peaks of the magnitude and I/Q waterfalls and of the raw
capture (bit-reversed order, frame offset taken from the peak position) are
on the same bin, and the OFDM log spectra of the magnitude and I/Q
waterfalls correlate.

  rf_iq_check.py --fs 10000000
"""
import argparse
import asyncio
import json

import numpy as np

import hwlib


def raw_spectrum(raw, peak_bin, br):
    """Mean power per bin of the 63 whole frames of a raw capture. The frame
    boundary is placed so that the peak lands on peak_bin."""
    pw = np.abs(raw) ** 2
    inv = np.empty_like(br)
    inv[br] = np.arange(len(br))
    pos = int(pw[:8 * hwlib.FRAME].reshape(8, -1).mean(0).argmax())
    off = (pos - int(inv[peak_bin])) % hwlib.FRAME
    f = pw[off:off + 63 * hwlib.FRAME].reshape(63, -1).mean(0)
    out = np.empty_like(f)
    out[br] = f
    return out


async def measure(host, name, br, expect=None):
    mag, iq = await asyncio.gather(hwlib.grab_ws(host, 'waterfall', 5),
                                   hwlib.grab_ws(host, 'iq-waterfall', 5))
    raw = hwlib.raw_capture(host)
    m = hwlib.mag_frames(mag).mean(0)
    c = hwlib.iq_words(iq)
    p = (np.abs(c) ** 2).mean(0)
    res = dict(name=name, frames=len(c), mag_peak=int(m.argmax()),
               iq_peak=sorted(set(map(int, (np.abs(c) ** 2).argmax(1))))[:4],
               corr_mag_iq_log=round(float(np.corrcoef(
                   np.log10(m + 1e-9), np.log10(p + 1))[0, 1]), 4))
    if expect is not None:
        res['expected_bin'] = expect
        r = raw_spectrum(raw, int(m.argmax()), br)
        res['raw_peak'] = int(r.argmax())
        # log spectra over the main lobe (the noise floor elsewhere is
        # uncorrelated between the two captures)
        k = slice(int(m.argmax()) - 4, int(m.argmax()) + 5)
        res['raw_vs_mag_log_corr'] = round(float(np.corrcoef(
            np.log10(r[k] + 1e-9), np.log10(m[k] + 1e-9))[0, 1]), 4)
    return res, m, p


async def run(a):
    br = hwlib.bitrev()
    fs = a.fs
    bw = min(int(0.8 * fs), 50_000_000) if fs > 2_500_000 else 2_000_000
    tx_s, rx_s = hwlib.save_settings(a.tx), hwlib.save_settings(a.rx)
    ok = True
    try:
        hwlib.configure(a.tx, a.rx, fs, bw, a.lo, a.rx_gain)
        if a.offset == 'auto':
            # carrier offset between the boards, from a single tone in the
            # time domain
            f0 = hwlib.tone_freq(fs, 2050)
            hwlib.start_tx(a.tx, hwlib.tone(fs, f0), 6000)
            offset = hwlib.td_freq(hwlib.td_capture(a.rx), fs) - f0
            print(f'carrier offset {offset:.0f} Hz (measured)', flush=True)
        else:
            offset = float(a.offset)
        for k in (2050, -6000):
            f = hwlib.tone_freq(fs, k)
            hwlib.start_tx(a.tx, hwlib.tone(fs, f), 6000)
            expect = int(round(2048 + (f + offset) / (fs / hwlib.FRAME)))
            r, _, _ = await measure(a.rx, f'cw {f:.0f} Hz', br, expect)
            good = (r['mag_peak'] in (expect - 1, expect, expect + 1)
                    # a tone near a half-bin position can put the peak of a
                    # single frame on either neighbouring bin
                    and all(abs(k - r['mag_peak']) <= 1 for k in r['iq_peak'])
                    and r['raw_vs_mag_log_corr'] > 0.99)
            ok &= good
            print(json.dumps(r), 'ok' if good else 'FAIL', flush=True)
        hwlib.stop_tx(a.tx)
        hwlib.ssh(a.tx, f'echo -89 > {hwlib.PHY}/out_voltage0_hardwaregain')
        hwlib.start_tx(a.tx, np.ones(hwlib.TONE_PERIOD, complex), 1)
        r, _, _ = await measure(a.rx, 'noise (TX -89 dB)', br)
        print(json.dumps(r), flush=True)
        hwlib.ssh(a.tx, f'echo 0 > {hwlib.PHY}/out_voltage0_hardwaregain')
        x = hwlib.ofdm(60, 1024, 128, 600, np.random.default_rng(3))
        hwlib.start_tx(a.tx, x, 3000)
        r, m, p = await measure(a.rx, 'ofdm 1024/128/600', br)
        f = (np.arange(hwlib.FRAME) - 2048) / hwlib.FRAME * fs + offset
        inb = np.abs(f) < 0.23 * fs
        out = np.abs(f) > 0.4 * fs
        for lab, s in (('mag', m), ('iq', p)):
            r[f'inband_over_outband_db_{lab}'] = round(float(
                10 * np.log10(s[inb].mean() / s[out].mean())), 1)
        good = r['corr_mag_iq_log'] > 0.98
        ok &= good
        print(json.dumps(r), 'ok' if good else 'FAIL', flush=True)
    finally:
        hwlib.tx_cleanup(a.tx)
        hwlib.restore_settings(a.tx, tx_s)
        hwlib.restore_settings(a.rx, rx_s)
        print('restored TX', hwlib.save_settings(a.tx) == tx_s,
              'RX', hwlib.save_settings(a.rx) == rx_s)
    return 0 if ok else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--fs', type=int, default=2_500_000,
                    help='sample rate, 2.5e6 ... 61.44e6')
    ap.add_argument('--tx', default='192.168.2.1')
    ap.add_argument('--rx', default='192.168.3.1')
    ap.add_argument('--lo', type=int, default=2_400_000_000)
    ap.add_argument('--rx-gain', type=int, default=40)
    ap.add_argument('--offset', default='auto',
                    help='carrier offset between the boards in Hz, or auto '
                    '(default): measured from a tone in the time domain. It '
                    'is about +-20 ppm of the LO for the two test boards and '
                    'drifts by a kHz or so, so a fixed value goes stale')
    raise SystemExit(asyncio.run(run(ap.parse_args())))


if __name__ == '__main__':
    main()
