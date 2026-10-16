#!/usr/bin/env python3
"""Check /iq-waterfall and the raw capture against /waterfall with the
AD9361 BIST tone (noise-free, every FFT frame identical).

Needs a board with the I/Q waterfall and raw capture (default 192.168.3.1).
Checks, for tones at (k + 1) * fs / 32 above DC (k = 0, 1, 3 by default):
 - the I/Q waterfall peak bin equals the magnitude waterfall peak bin,
 - the log spectra correlate,
 - every value of the raw capture appears exactly 64 times as often as in
   one I/Q waterfall frame (the raw capture is 64 frames of the same data).
"""
import argparse
import asyncio
from collections import Counter

import numpy as np

import hwlib

DBG = '/sys/kernel/debug/iio/iio:device0/bist_tone'


async def run(host, ks):
    fs = int(hwlib.ssh(host, f'cat {hwlib.PHY}/in_voltage_sampling_frequency'))
    ok = True
    try:
        for k in ks:
            hz = (k + 1) * fs // 32
            hwlib.ssh(host, f'echo "2 {hz} 6 0" > {DBG}')
            await asyncio.sleep(1.5)
            mag, iq = await asyncio.gather(
                hwlib.grab_ws(host, 'waterfall', 4),
                hwlib.grab_ws(host, 'iq-waterfall', 4))
            raw = hwlib.raw_capture(host)
            m = hwlib.mag_frames(mag)[-1]
            c = hwlib.iq_words(iq)[-1]
            p = np.abs(c) ** 2
            sel = m > m.max() * 1e-6
            corr = np.corrcoef(np.log10(m[sel] + 1e-9),
                               np.log10(p[sel] + 1e-9))[0, 1]
            ci = Counter(zip(c.real.astype(int).tolist(),
                             c.imag.astype(int).tolist()))
            cr = Counter(zip(raw.real.astype(int).tolist(),
                             raw.imag.astype(int).tolist()))
            keys = set(ci) | set(cr)
            match = sum(cr.get(x, 0) == 64 * ci.get(x, 0) for x in keys)
            frames = {raw[i * hwlib.FRAME:(i + 1) * hwlib.FRAME].tobytes()
                      for i in range(64)}
            good = (m.argmax() == p.argmax() and corr > 0.999
                    and match == len(keys) and len(frames) == 1)
            ok &= good
            print(f'tone {hz} Hz: peak mag {m.argmax()} iq {p.argmax()} '
                  f'log-corr {corr:.7f} raw multiset {match}/{len(keys)} '
                  f'distinct raw frames {len(frames)} '
                  f'{"ok" if good else "FAIL"}')
    finally:
        hwlib.ssh(host, f'echo "0 0 0 0" > {DBG}')
    return 0 if ok else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--host', default='192.168.3.1')
    ap.add_argument('--k', type=int, nargs='+', default=[0, 1, 3])
    a = ap.parse_args()
    raise SystemExit(asyncio.run(run(a.host, a.k)))


if __name__ == '__main__':
    main()
