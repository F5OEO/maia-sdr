"""F17 test: what RX2 carries on a Pluto+ when DDC routing is on.

The AD9363 BIST tone (mode 2, injected into RX) is set to (i+1) * fs/32.
With routing off, RX1 and RX2 are
captured at the full rate; with routing on, RX1 is the DDC output (tuned 100
kHz below the tone, so the
tone is at +100 kHz) and RX2 is whatever the packer delivers at the DDC
strobe. For each capture this
reports, per channel pair, the strongest frequency, its level in dBFS and
the level of everything else.
Usage: rx2test.py <label> [host] -> results/<label>-rx2.json
"""
import json
import os
import subprocess
import sys
import time
import numpy as np

LABEL = sys.argv[1]
HOST = sys.argv[2] if len(sys.argv) > 2 else '192.168.4.1'
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


def peak(z, rate):
    """Strongest bin (Hz), its level and the rest, in dBFS (full scale = 2048
    for 12-bit data)."""
    n = len(z)
    w = np.blackman(n)
    spec = np.abs(np.fft.fftshift(np.fft.fft(z * w))) / (np.sum(w) * 2048)
    f = np.fft.fftshift(np.fft.fftfreq(n, 1 / rate))
    k = int(np.argmax(spec))
    p = 20 * np.log10(spec[k] + 1e-12)
    mask = np.ones(n, bool)
    mask[max(0, k - 8):k + 9] = False
    rest = 20 * np.log10(np.max(spec[mask]) + 1e-12)
    return {
        'peak_hz': round(
            float(
                f[k]), 1), 'peak_dbfs': round(
            float(p), 1), 'next_dbfs': round(
                    float(rest), 1), 'rms_lsb': round(
                        float(
                            np.sqrt(
                                np.mean(
                                    np.abs(z) ** 2))), 1)}


def capture(n):
    raw = sh(f'iio_readdev -b 65536 -s {n} cf-ad9361-lpc '
             f'voltage0 voltage1 voltage2 voltage3 > /tmp/rx2.bin; '
             f'cat /tmp/rx2.bin; rm -f /tmp/rx2.bin', timeout=60)
    d = np.frombuffer(raw, dtype='<i2').reshape(-1, 4).astype(float)
    return d[:, 0] + 1j * d[:, 1], d[:, 2] + 1j * d[:, 3]


fs = int(sh(f'cat {PHY}/in_voltage_sampling_frequency').decode())
out = {'fs': fs, 'cases': []}
api({'enabled': False, 'frequency': 0.0})
for i in range(4):
    tone = (i + 1) * fs // 32
    api({'enabled': False, 'frequency': 0.0})
    sh(f'echo "2 {tone} 6 0" > {DBG}/bist_tone')
    time.sleep(0.3)
    r1, r2 = capture(65536)
    case = {
        'tone_index': i, 'tone_hz': tone, 'routing_off': {
            'rx1': peak(
                r1, fs), 'rx2': peak(
                r2, fs)}}
    cfg = api({'enabled': True, 'frequency': float(tone - 100000)})
    time.sleep(0.3)
    fout = cfg['output_sampling_frequency']
    r1, r2 = capture(65536)
    case['ddc_rate'] = fout
    # where an undecimated, unfiltered RX2 tone would land when picked every
    # decimation-th sample
    alias = ((tone + fout / 2) % fout) - fout / 2
    case['rx2_expected_alias_hz'] = round(alias, 1)
    case['routing_on'] = {'rx1': peak(r1, fout), 'rx2': peak(r2, fout),
                          'rx2_all_zero': bool(np.all(r2 == 0))}
    out['cases'].append(case)
api({'enabled': False, 'frequency': 0.0})
sh(f'echo "0 0 0 0" > {DBG}/bist_tone')
os.makedirs(f'{HERE}/results', exist_ok=True)
json.dump(out, open(f'{HERE}/results/{LABEL}-rx2.json', 'w'), indent=1)
for c in out['cases']:
    print(
        c['tone_index'],
        c['tone_hz'],
        'off rx1',
        c['routing_off']['rx1']['peak_hz'],
        'rx2',
        c['routing_off']['rx2']['peak_hz'],
        '| on rx1',
        c['routing_on']['rx1']['peak_hz'],
        c['routing_on']['rx1']['peak_dbfs'],
        'rx2',
        c['routing_on']['rx2']['peak_hz'],
        c['routing_on']['rx2']['peak_dbfs'],
        'expected alias',
        c['rx2_expected_alias_hz'],
        'rx2 zero',
        c['routing_on']['rx2_all_zero'])
