"""F5 test: DC bias of the DDC output delivered to IIO.

The AD9363 BIST tone (mode 2, injected into RX) goes through the DDC tuned
100 kHz below it, so the DDC
output is a pure tone at +100 kHz. Its mean over millions of samples is
essentially zero; what remains is
the bias of the 16-to-12-bit step. Truncation (>> 4) gives about -15/32 =
-0.47 LSB on I and Q, rounding
to nearest gives about 0. Captures CS16 (voltage0 voltage1) with routing on.
Usage: dcbias.py <label> [host] [captures] -> results/<label>-dcbias.json
"""
import json
import os
import subprocess
import sys
import time
import numpy as np

LABEL = sys.argv[1]
HOST = sys.argv[2] if len(sys.argv) > 2 else '192.168.4.1'
NCAP = int(sys.argv[3]) if len(sys.argv) > 3 else 5
HERE = os.path.dirname(os.path.abspath(__file__))
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
PHY = '/sys/bus/iio/devices/iio:device0'


def sh(cmd, timeout=120):
    return subprocess.run(
        SSH + [cmd],
        capture_output=True,
        timeout=timeout).stdout


def api(patch):
    subprocess.run(['curl',
                    '-s',
                    '-X',
                    'PATCH',
                    '-H',
                    'Content-Type: application/json',
                    '-d',
                    json.dumps(patch),
                    f'http://{HOST}/api/ddc/config'],
                   capture_output=True,
                   timeout=20)
    return json.loads(subprocess.run(['curl',
                                      '-s',
                                      f'http://{HOST}/api/ddc/config'],
                                     capture_output=True,
                                     text=True).stdout)


fs = int(sh(f'cat {PHY}/in_voltage_sampling_frequency').decode())
out = {'fs': fs, 'levels': []}
for level in (6, 12, 18):
    tone = fs // 32
    sh(f'echo "2 {tone} {level} 0" > {DBG}/bist_tone')
    cfg = api({'enabled': True, 'frequency': float(tone - 100000)})
    time.sleep(0.5)
    n = int(cfg['output_sampling_frequency'])
    caps = []
    for _ in range(NCAP):
        raw = sh(f'iio_readdev -b 262144 -s {n} cf-ad9361-lpc '
                 f'voltage0 voltage1 > /tmp/dc.bin; cat /tmp/dc.bin; '
                 f'rm -f /tmp/dc.bin')
        d = np.frombuffer(raw, dtype='<i2').reshape(-1, 2).astype(float)
        caps.append({'mean_i': float(d[:, 0].mean()),
                     'mean_q': float(d[:, 1].mean()),
                     'amp': float(np.median(np.hypot(d[:, 0], d[:, 1]))),
                     'samples': len(d),
                     'max_abs': int(np.abs(d).max())})
    mi = np.array([c['mean_i'] for c in caps])
    mq = np.array([c['mean_q'] for c in caps])
    out['levels'].append({'bist_level_db': level,
                          'ddc_rate': cfg['output_sampling_frequency'],
                          'captures': caps,
                          'mean_i': round(float(mi.mean()), 4),
                          'mean_q': round(float(mq.mean()), 4),
                          'spread_i': round(float(mi.std()), 4),
                          'spread_q': round(float(mq.std()), 4),
                          'amp': round(float(np.mean(
                              [c['amp'] for c in caps])), 1),
                          'max_abs': max(c['max_abs'] for c in caps)})
api({'enabled': False, 'frequency': 0.0})
sh(f'echo "0 0 0 0" > {DBG}/bist_tone')
os.makedirs(f'{HERE}/results', exist_ok=True)
json.dump(out, open(f'{HERE}/results/{LABEL}-dcbias.json', 'w'), indent=1)
for lv in out['levels']:
    print(lv['bist_level_db'], 'dB  amp', lv['amp'],
          ' mean I', lv['mean_i'], '+-', lv['spread_i'],
          ' mean Q', lv['mean_q'], '+-', lv['spread_q'],
          ' max|x|', lv['max_abs'])
