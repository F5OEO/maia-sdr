#!/usr/bin/env python3
"""Phase between consecutive frames of the I/Q waterfall with a real signal.

The I/Q waterfall holds one FFT frame (the last of the `number_integrations`
frames of each integration), so consecutive frames are exactly
`number_integrations * 4096` input samples apart. The phase of one tone from
frame to frame is dominated by the drift of the two board references (tens
of Hz), so it cannot be predicted. The phase of the product of two tones
from the same transmit buffer, X1 * conj(X2), rotates at exactly their
frequency difference as seen by the receiver, and the reference drift
cancels. The check measures that rotation per frame and compares it with
the prediction:

    theta = 2 pi (f1 - f2) (1 + delta) nint 4096 / fs     (mod 2 pi)

where delta is the sample clock ratio of the two boards. It is taken from
the carrier offset (the LO and the sample clock come from the same
reference): delta = (f_measured - f_sent) / (f_sent + LO) for a single tone
measured in the time domain. A dropped frame or a spacing that is off by
one FFT frame (4096 samples; the tone spacing is not a whole number of bins
so this changes the phase) shows up as a different rotation.

Reported: measured mean rotation minus prediction, its scatter, the number
of frames that deviate by more than 0.3 rad, the arrival times of the
frames, and for information the scatter of the single-tone second
difference (limited by the reference drift).
Radio settings and the number of integrations are restored at the end.

  rf_iq_frame_phase_check.py --fs 10000000 --tx 192.168.2.1 --rx 192.168.3.1
"""
import argparse
import asyncio
import json
import time

import numpy as np
import websockets

import hwlib

FR = hwlib.FRAME
DK = 51        # tone spacing in TX buffer periods: 51 * 4096 / 25000 bins


async def grab_timed(host, secs):
    out = []
    async with websockets.connect(f'ws://{host}/iq-waterfall',
                                  max_size=None) as ws:
        end = time.monotonic() + secs
        while time.monotonic() < end:
            m = await asyncio.wait_for(ws.recv(), 20)
            if isinstance(m, bytes) and len(m) == 4 * FR:
                out.append((time.monotonic(), m))
    return out


def wrap(x):
    return np.angle(np.exp(1j * x))


def analyse(fs, nint, f1, f2, delta, frames, times):
    c = hwlib.iq_words(frames)
    p = (np.abs(c) ** 2).mean(0)
    # the two strongest peaks, at least 4 bins apart
    k1 = int(p.argmax())
    q = p.copy()
    q[max(0, k1 - 4):k1 + 5] = 0
    k2 = int(q.argmax())
    lo, hi = sorted((k1, k2))
    # tone 1 is the lower-frequency one
    kb = {'lo': lo, 'hi': hi}
    x1, x2 = c[:, kb['lo']], c[:, kb['hi']]
    f_lo, f_hi = sorted((f1, f2))
    prod = x1 * np.conj(x2)
    d = wrap(np.angle(prod[1:] * np.conj(prod[:-1])))
    dt = nint * FR / fs
    theta = wrap(2 * np.pi * (f_lo - f_hi) * (1 + delta) * dt)
    mean_d = np.angle(np.mean(np.exp(1j * d)))
    dev = wrap(d - theta)
    arr = np.diff(times)
    d1 = wrap(np.angle(x1[1:] * np.conj(x1[:-1])))
    sd = wrap(np.diff(d1))
    return dict(
        nint=nint, frames=len(c), bins=[lo, hi],
        frame_period_ms=round(dt * 1e3, 2),
        arrival_ms_median=round(float(np.median(arr)) * 1e3, 1),
        arrival_ms_max=round(float(arr.max()) * 1e3, 1),
        theta_pred_rad=round(float(theta), 4),
        theta_meas_rad=round(float(mean_d), 4),
        meas_minus_pred_rad=round(float(wrap(mean_d - theta)), 4),
        scatter_rad=round(float(np.std(wrap(d - mean_d))), 4),
        frames_off_gt_0p3_rad=int(np.sum(np.abs(dev) > 0.3)),
        amp_ratio_db=round(float(10 * np.log10(
            np.mean(np.abs(x1) ** 2) / np.mean(np.abs(x2) ** 2))), 2),
        single_tone_second_diff_rms_rad=round(float(np.sqrt(
            np.mean(sd ** 2))), 3))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--fs', type=int, default=10_000_000)
    ap.add_argument('--tx', default='192.168.2.1')
    ap.add_argument('--rx', default='192.168.3.1')
    ap.add_argument('--lo', type=int, default=2_400_000_000)
    ap.add_argument('--rx-gain', type=int, default=40)
    ap.add_argument('--frame-ms', type=float, default=100.0,
                    help='target spacing of the I/Q frames')
    ap.add_argument('--secs', type=float, default=10.0)
    a = ap.parse_args()
    fs = a.fs
    bw = min(int(0.8 * fs), 50_000_000) if fs > 2_500_000 else 2_000_000
    tx_s, rx_s = hwlib.save_settings(a.tx), hwlib.save_settings(a.rx)
    nint0 = json.loads(hwlib.http(a.rx, 'GET', '/api/spectrometer'))[
        'number_integrations']
    ok = True
    try:
        hwlib.configure(a.tx, a.rx, fs, bw, a.lo, a.rx_gain)
        k1 = 2050
        f1 = hwlib.tone_freq(fs, k1)
        f2 = hwlib.tone_freq(fs, k1 + DK)
        # sample clock ratio from the carrier offset of a single tone
        hwlib.start_tx(a.tx, hwlib.tone(fs, f1), 6000)
        fm = hwlib.td_freq(hwlib.td_capture(a.rx), fs)
        delta = (fm - f1) / (f1 + a.lo)
        # frames per integration; avoid a rotation near 0 or pi so that a
        # dropped frame or a one-FFT-frame error cannot go unnoticed
        nint = int(np.clip(round(a.frame_ms * 1e-3 * fs / FR), 1, 1023))
        for n in range(nint, nint - 20, -1):
            th = 2 * np.pi * (f1 - f2) * (1 + delta) * n * FR / fs
            if abs(np.sin(wrap(th) / 2)) > 0.3:
                nint = n
                break
        hwlib.http(a.rx, 'PATCH', '/api/spectrometer',
                   json.dumps({'number_integrations': nint}).encode())
        hwlib.start_tx(a.tx, hwlib.tone(fs, f1) + hwlib.tone(fs, f2), 6000)
        time.sleep(1)
        got = asyncio.run(grab_timed(a.rx, a.secs))
        times = np.array([t for t, _ in got])
        r = analyse(fs, nint, f1, f2, delta, [m for _, m in got], times)
        r['delta_ppm'] = round(delta * 1e6, 3)
        r['carrier_offset_hz'] = round(fm - f1, 1)
        good = (r['frames'] >= 20 and r['frames_off_gt_0p3_rad'] == 0
                and abs(r['meas_minus_pred_rad']) < 0.1
                and r['scatter_rad'] < 0.1)
        ok &= good
        print(f'fs {fs}:', json.dumps(r), 'ok' if good else 'FAIL',
              flush=True)
    finally:
        hwlib.http(a.rx, 'PATCH', '/api/spectrometer',
                   json.dumps({'number_integrations': nint0}).encode())
        hwlib.tx_cleanup(a.tx)
        hwlib.restore_settings(a.tx, tx_s)
        hwlib.restore_settings(a.rx, rx_s)
        print('restored TX', hwlib.save_settings(a.tx) == tx_s,
              'RX', hwlib.save_settings(a.rx) == rx_s,
              'nint', json.loads(hwlib.http(
                  a.rx, 'GET', '/api/spectrometer'))[
                      'number_integrations'] == nint0)
    raise SystemExit(0 if ok else 1)


if __name__ == '__main__':
    main()
