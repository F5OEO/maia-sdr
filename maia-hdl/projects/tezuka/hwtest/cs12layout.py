"""Check the CS12 stream contract (doc/cs12-stream.md) on hardware.

The AD9363 BIST tone (mode 2, injected into RX) at fs/32 is captured in CS12
mode (only voltage1 enabled on
cf-ad9361-lpc, DDC routing off). The script decodes the byte stream as
documented and checks:
  - sync bursts (20-byte MAGIC + uint32 counter) every 786432 bytes = 32768
    bursts = 262144 sample slots,
    counter +1 each;
  - decoded data is the tone (residual of a single complex-sinusoid fit, per
    sync period);
  - across each sync burst the tone phase from the last sample before it to
    the first sample after it advances
    by 9 sample periods if the burst REPLACES 8 samples, or by 1 if it were
    inserted (90 degrees apart at fs/32).
Usage: cs12layout.py [host] [periods] [label]
  -> prints a summary, writes results/[<label>-]cs12layout.json
"""
import json
import os
import subprocess
import sys
import numpy as np

HOST = sys.argv[1] if len(sys.argv) > 1 else '192.168.4.1'
PERIODS = int(sys.argv[2]) if len(sys.argv) > 2 else 4
LABEL = sys.argv[3] + '-' if len(sys.argv) > 3 else ''
HERE = os.path.dirname(os.path.abspath(__file__))
MAGIC = bytes.fromhex('A15C1EABD2C5EF12379A4D6BE1F08A3C567D9124')
# bytes per burst: 8 I and 8 Q samples of 12 bits
BURST = 24
SSH = [
    'sshpass',
    '-p',
    'analog',
    'ssh',
    '-o',
    'StrictHostKeyChecking=no',
    '-o',
    'UserKnownHostsFile=/dev/null',
    '-o',
    'LogLevel=ERROR',
    f'root@{HOST}']
DBG = '/sys/kernel/debug/iio/iio:device0'


def sh(cmd, timeout=120):
    return subprocess.run(
        SSH + [cmd],
        capture_output=True,
        timeout=timeout).stdout


def unpack_burst(b):
    """24 bytes -> 8 complex samples, as documented: per cycle 2 I bytes then 2
    Q bytes; the 12 I bytes (and the
    12 Q bytes) form a 96-bit big-endian word holding samples 0..7, oldest
    in the top 12 bits."""
    i96 = int.from_bytes(bytes(b[c * 4 + k]
                         for c in range(6) for k in (0, 1)), 'big')
    q96 = int.from_bytes(bytes(b[c * 4 + k]
                         for c in range(6) for k in (2, 3)), 'big')
    out = []
    for s in range(8):
        sh_ = 84 - 12 * s
        iv, qv = (i96 >> sh_) & 0xFFF, (q96 >> sh_) & 0xFFF
        iv -= 4096 if iv & 0x800 else 0
        qv -= 4096 if qv & 0x800 else 0
        out.append(complex(iv, qv))
    return out


fs = int(sh('cat /sys/bus/iio/devices/iio:device0/'
            'in_voltage_sampling_frequency'))
tone = fs // 32
routing = json.loads(subprocess.run(['curl',
                                     '-s',
                                     f'http://{HOST}/api/ddc/config'],
                                    capture_output=True,
                                    text=True).stdout).get('routing')
assert routing in (False, None), 'DDC routing must be off'
sh(f'echo "2 {tone} 6 0" > {DBG}/bist_tone')
period_bytes = 786432
# iio_readdev counts 16-bit voltage1 samples. Use a 2 MiB buffer: with 128 KiB
# the reader drops whole sync periods at 30.72 MS/s (in a third of captures)
nsamp = (PERIODS + 1) * period_bytes // 2
raw = sh(f'iio_readdev -b 1048576 -s {nsamp} cf-ad9361-lpc voltage1 '
         f'> /tmp/c12.bin 2>/dev/null; cat /tmp/c12.bin; '
         f'rm -f /tmp/c12.bin', timeout=120)
sh(f'echo "0 0 0 0" > {DBG}/bist_tone')

pos, i = [], raw.find(MAGIC)
while i >= 0:
    pos.append(i)
    i = raw.find(MAGIC, i + 1)
gaps = sorted(set(b - a for a, b in zip(pos, pos[1:])))
ctr = [int.from_bytes(raw[p + 20:p + 24], 'little') for p in pos]
res = {'fs': fs,
       'tone_hz': tone,
       'bytes': len(raw),
       'magic_count': len(pos),
       'magic_gaps': gaps,
       'counter_steps': sorted(set(b - a for a,
                                   b in zip(ctr,
                                            ctr[1:]))),
       'lossless': all(g == period_bytes for g in gaps) and all(
           y == x + 1 for x, y in zip(ctr, ctr[1:])),
       'periods': []}

w = 2 * np.pi * tone / fs
for a, b in zip(pos, pos[1:]):
    bursts = [raw[o:o + BURST] for o in range(a + BURST, b, BURST)]
    x = np.array([s for bb in bursts for s in unpack_burst(bb)])
    n = np.arange(len(x))
    # complex tone fit: x ~ A exp(j w n) (sign of w from data)
    best = None
    for sgn in (1, -1):
        e = np.exp(1j * sgn * w * n)
        A = np.vdot(e, x) / len(x)
        r = np.sqrt(np.mean(np.abs(x - A * e) ** 2)) / abs(A)
        if best is None or r < best[0]:
            best = (r, sgn, A)
    r, sgn, A = best
    res['periods'].append({'samples': len(x),
                           'amplitude': round(abs(A),
                                              1),
                           'rel_rms_residual': round(float(r),
                                                     4),
                           'sign': sgn,
                           'phase0': float(np.angle(A)),
                           'first': x[:8].tolist()})
# phase continuity across each sync burst: last sample of period k, first
# sample of period k+1
sgn = res['periods'][0]['sign']
steps = []
for k in range(len(res['periods']) - 1):
    p0, p1 = res['periods'][k], res['periods'][k + 1]
    end_phase = p0['phase0'] + sgn * w * (p0['samples'] - 1)
    dphi = (p1['phase0'] - end_phase) % (2 * np.pi)
    # in samples, modulo the 32-sample tone period
    steps.append(round(dphi / (sgn * w) % 32, 2))
res['phase_step_samples_across_sync'] = steps
for p in res['periods']:
    p.pop('first')
os.makedirs(f'{HERE}/results', exist_ok=True)
json.dump(res, open(f'{HERE}/results/{LABEL}cs12layout.json', 'w'), indent=1)
print(json.dumps({k: v for k, v in res.items() if k != 'periods'}))
if not res['lossless']:
    print('WARNING: the reader lost data (sync gap != %d or counter jump); '
          'repeat the capture' % period_bytes)
for p in res['periods']:
    print(p)
