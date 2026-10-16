#!/usr/bin/env python3
"""Phase check of the raw capture and the I/Q waterfall with a real CW tone.

The transmit board sends a CW tone through a cable into the board under
test. For each tone:
 1. The frequency is measured in the time domain (libiio, before and after
    the raw capture; the two board references drift by tens of Hz).
 2. The raw capture (63 consecutive frames) gives the frame-to-frame phase
    advance of the peak bin, i.e. the tone frequency modulo the bin width,
    with the bin ambiguity resolved from the time-domain value. It must
    agree with 1. within the drift.
 3. The bins around the peak, relative to the peak bin, are compared with a
    numpy model of the windowed (Blackman-Harris) FFT; phase and amplitude
    residuals are reported for bins -3..3.
 4. The I/Q waterfall neighbour phases are compared with the raw capture.
Radio settings of both boards are restored at the end.

  rf_phase_check.py --fs 10000000
"""
import argparse

import numpy as np

import hwlib

FR = hwlib.FRAME
MS = list(range(-6, 7))


def bh_window(n):
    k = np.arange(n)
    return (0.35875 - 0.48829 * np.cos(2 * np.pi * k / n)
            + 0.14128 * np.cos(4 * np.pi * k / n)
            - 0.01168 * np.cos(6 * np.pi * k / n))


def analyse(fs, ftd, raw, iq, br):
    """Returns a dict of results for one tone."""
    t_frame = FR / fs
    bin_exp = int(round(2048 + ftd / fs * FR))
    inv = np.empty_like(br)
    inv[br] = np.arange(FR)
    pw = np.abs(raw) ** 2
    pos = int(pw[:8 * FR].reshape(8, -1).mean(0).argmax())
    off = (pos - int(inv[bin_exp])) % FR
    c = raw[off:off + 63 * FR].reshape(63, FR)     # c[frame, raw index]
    kpk = int(np.abs(c).mean(0).argmax())
    bpk = int(br[kpk])
    pk = c[:, kpk]
    dphi = np.angle(pk[1:] * np.conj(pk[:-1]))
    mean_dphi = np.angle(np.mean(np.exp(1j * dphi)))
    scatter = float(np.std(np.angle(np.exp(1j * (dphi - mean_dphi)))))
    n = np.round(ftd * t_frame - mean_dphi / (2 * np.pi))
    f_phase = (mean_dphi / (2 * np.pi) + n) / t_frame
    # bins around the peak relative to the peak bin
    rel_raw = []
    for fr in c:
        v = np.zeros(FR, complex)
        v[br] = fr
        rel_raw.append([v[bpk + m] / v[bpk] for m in MS])
    rel_raw = np.mean(rel_raw, 0)
    ci = iq
    pb = int(np.abs(ci).mean(0).argmax())
    rel_iq = np.mean([[x[pb + m] / x[pb] for m in MS] for x in ci], 0)
    t = np.arange(FR)
    win = bh_window(FR)
    best = None
    for f in np.arange(f_phase - 1.5 * fs / FR, f_phase + 1.5 * fs / FR,
                       fs / FR / 100):
        x = np.fft.fftshift(np.fft.fft(np.exp(2j * np.pi * f * t / fs)
                                       * win))
        p = int(np.abs(x).argmax())
        rel = np.array([x[p + m] / x[p] for m in MS])
        e = np.sum(np.abs(rel - rel_raw) ** 2)
        if best is None or e < best[0]:
            best = (e, rel)
    rel_model = best[1]
    near = slice(3, 10)
    ph_err = np.angle(rel_raw * np.conj(rel_model)) * 180 / np.pi
    amp_err = 20 * np.log10(np.abs(rel_raw) / np.abs(rel_model))
    iq_vs_raw = np.angle(rel_iq * np.conj(rel_raw)) * 180 / np.pi
    return dict(
        peak_bin=bpk, iq_peak_bin=pb, expected_bin=bin_exp,
        f_timedomain_hz=round(float(ftd), 1),
        f_phase_hz=round(float(f_phase), 1),
        f_diff_hz=round(float(f_phase - ftd), 1),
        dphi_scatter_rad=round(scatter, 4),
        model_max_phase_err_deg=round(float(np.abs(ph_err[near]).max()), 2),
        model_max_amp_err_db=round(float(np.abs(amp_err[near]).max()), 2),
        iq_vs_raw_max_phase_diff_deg=round(
            float(np.abs(iq_vs_raw[near]).max()), 1))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--fs', type=int, default=2_500_000)
    ap.add_argument('--tx', default='192.168.2.1')
    ap.add_argument('--rx', default='192.168.3.1')
    ap.add_argument('--lo', type=int, default=2_400_000_000)
    ap.add_argument('--rx-gain', type=int, default=40)
    ap.add_argument('--max-drift-hz', type=float, default=150.0,
                    help='allowed |phase - time domain| difference')
    a = ap.parse_args()
    fs = a.fs
    bw = min(int(0.8 * fs), 50_000_000) if fs > 2_500_000 else 2_000_000
    br = hwlib.bitrev()
    tx_s, rx_s = hwlib.save_settings(a.tx), hwlib.save_settings(a.rx)
    ok = True
    try:
        hwlib.configure(a.tx, a.rx, fs, bw, a.lo, a.rx_gain)
        import asyncio
        for k in (2050, 2053, -6000):
            f = hwlib.tone_freq(fs, k)
            hwlib.start_tx(a.tx, hwlib.tone(fs, f), 6000)
            f0 = hwlib.td_freq(hwlib.td_capture(a.rx), fs)
            iq = hwlib.iq_words(asyncio.run(
                hwlib.grab_ws(a.rx, 'iq-waterfall', 4)))
            raw = hwlib.raw_capture(a.rx)
            f1 = hwlib.td_freq(hwlib.td_capture(a.rx), fs)
            r = analyse(fs, (f0 + f1) / 2, raw, iq, br)
            r['td_drift_hz'] = round(float(abs(f1 - f0)), 1)
            good = (abs(r['f_diff_hz']) < max(a.max_drift_hz,
                                              r['td_drift_hz'])
                    and r['dphi_scatter_rad'] < 0.05
                    and r['peak_bin'] == r['iq_peak_bin'])
            ok &= good
            print(f'tone {f:.1f} Hz sent:', r, 'ok' if good else 'FAIL',
                  flush=True)
    finally:
        hwlib.tx_cleanup(a.tx)
        hwlib.restore_settings(a.tx, tx_s)
        hwlib.restore_settings(a.rx, rx_s)
        print('restored TX', hwlib.save_settings(a.tx) == tx_s,
              'RX', hwlib.save_settings(a.rx) == rx_s)
    raise SystemExit(0 if ok else 1)


if __name__ == '__main__':
    main()
