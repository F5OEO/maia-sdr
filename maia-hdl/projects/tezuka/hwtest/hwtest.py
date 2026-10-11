"""Pluto+ hardware test for maia-sdr refactor F1 (CS12 vs DDC routing) and F4 (sweeper).

Usage: hwtest.py <label> [host]   -> writes results/<label>.json and prints a summary.
Leaves the board as found: DDC routing disabled, EMIO 63-66 back to inputs.
"""
import json, os, subprocess, sys, time

LABEL = sys.argv[1]
HOST = sys.argv[2] if len(sys.argv) > 2 else '192.168.4.1'
HERE = os.path.dirname(os.path.abspath(__file__))
MAGIC = bytes.fromhex('A15C1EABD2C5EF12379A4D6BE1F08A3C567D9124')
CS12_PERIOD = 786432                    # bytes between sync bursts as measured through util_cpack2
SSH = ['sshpass', '-p', 'analog', 'ssh', '-o', 'StrictHostKeyChecking=no',
       '-o', 'UserKnownHostsFile=/dev/null', '-o', 'LogLevel=ERROR', f'root@{HOST}']


def sh(cmd, inp=None, timeout=120):
    r = subprocess.run(SSH + [cmd], input=inp, capture_output=True, timeout=timeout)
    return r.returncode, r.stdout, r.stderr.decode(errors='replace')


def api_routing(enable):
    r = subprocess.run(['curl', '-s', '-o', '/dev/null', '-w', '%{http_code}', '-X', 'PATCH',
                        '-H', 'Content-Type: application/json', '-d', json.dumps({'enabled': enable}),
                        f'http://{HOST}/api/ddc/config'], capture_output=True, text=True, timeout=20)
    reg = sh('devmem 0x790200BC 32')[1].decode().strip()
    return {'http': r.stdout, 'reg_0x790200BC': reg}


def capture(chans, nbytes, tmo=15):
    """iio_readdev on the board; returns bytes received, seconds, and the data."""
    nsamp = nbytes // (2 * len(chans.split()))
    cmd = (f'rm -f /tmp/cap.bin; t0=$(cut -d" " -f1 /proc/uptime); '
           f'timeout {tmo} iio_readdev -b 65536 -s {nsamp} cf-ad9361-lpc {chans} > /tmp/cap.bin 2>/tmp/cap.err; rc=$?; '
           f't1=$(cut -d" " -f1 /proc/uptime); echo "$rc $t0 $t1 $(wc -c < /tmp/cap.bin)"')
    out = sh(cmd, timeout=tmo + 30)[1].decode().split()
    rc, t0, t1, n = int(out[0]), float(out[1]), float(out[2]), int(out[3])
    data = sh('cat /tmp/cap.bin', timeout=60)[1] if n else b''
    err = sh('cat /tmp/cap.err')[1].decode(errors='replace').strip()[-300:]
    sh('rm -f /tmp/cap.bin')
    return {'rc': rc, 'bytes': n, 'seconds': round(t1 - t0, 2), 'stderr': err}, data


def magic_stats(data):
    pos, i = [], data.find(MAGIC)
    while i >= 0:
        pos.append(i); i = data.find(MAGIC, i + 1)
    gaps = sorted(set(b - a for a, b in zip(pos, pos[1:])))
    return {'magic_count': len(pos), 'magic_gaps': gaps}


def nonzero_fraction(data):
    return round(sum(1 for b in data[:200000] if b) / max(1, min(len(data), 200000)), 3)


FS = os.environ.get('FS')                # optional AD9363 sample rate for the whole run, e.g. 61440000
PHY = sh('for d in /sys/bus/iio/devices/iio:device*; do [ "$(cat $d/name)" = ad9361-phy ] && echo $d; done')[1].decode().strip()
FS_ATTR = f'{PHY}/in_voltage_sampling_frequency'
FS_ORIG = sh(f'cat {FS_ATTR}')[1].decode().strip()
if FS:
    sh(f'echo {FS} > {FS_ATTR}'); time.sleep(2)
res = {'label': LABEL, 'time': time.strftime('%Y-%m-%d %H:%M:%S'),
       'sampling_frequency': sh(f'cat {FS_ATTR}')[1].decode().strip(),
       'ddc_config': json.loads(subprocess.run(['curl', '-s', f'http://{HOST}/api/ddc/config'],
                                               capture_output=True, text=True).stdout or '{}')}
res['ddc_config'].pop('fir1', None); res['ddc_config'].pop('fir2', None); res['ddc_config'].pop('fir3', None)
res['board'] = sh('hostname; uname -v; md5sum /boot/system_top.bin /boot/devicetree.dtb /boot/uramdisk.image.xz; '
                  'cat /etc/fw_version 2>/dev/null')[1].decode().strip().splitlines()

# ---- F4: sweeper profile cadence (/waterfall f[0]) ----
r = subprocess.run([sys.executable, f'{HERE}/wfprofile.py', HOST, '48'],
                   capture_output=True, text=True, timeout=120)
res['F4_waterfall_profile'] = json.loads(r.stdout) if r.returncode == 0 else {'error': r.stderr[-500:]}

# ---- F4: pads with CTRL_IN1..3 and EN_AGC as PS outputs driven low (as sweep mode does for 63-65) ----
sh('cat > /tmp/agcmon && chmod +x /tmp/agcmon', inp=open(f'{HERE}/agcmon', 'rb').read())
sh('gpioset gpiochip0 63=0 64=0 65=0 66=0')
res['F4_pads_outputs_low'] = sh('/tmp/agcmon 10', timeout=60)[1].decode().strip().splitlines()
sh('gpioget gpiochip0 63 64 65 66')          # back to inputs
res['F4_pads_restored'] = sh('/tmp/agcmon 1')[1].decode().strip().splitlines()[0]

# ---- F1: CS16 / CS12 with DDC routing off and on ----
f1 = {}
for routing in (False, True):
    f1[f'routing_{"on" if routing else "off"}_api'] = api_routing(routing)
    meta, data = capture('voltage0 voltage1', 4 * 1536000)       # ~1 s at the DDC rate
    meta['msps'] = round(meta['bytes'] / 4 / meta['seconds'] / 1e6, 3) if meta['seconds'] else None
    meta['nonzero'] = nonzero_fraction(data)
    f1[f'cs16_routing_{"on" if routing else "off"}'] = meta
    meta, data = capture('voltage1', 5 * CS12_PERIOD)            # 5 sync periods
    meta.update(magic_stats(data)); meta['nonzero'] = nonzero_fraction(data)
    f1[f'cs12_routing_{"on" if routing else "off"}'] = meta
f1['restore'] = api_routing(False)
if FS:
    sh(f'echo {FS_ORIG} > {FS_ATTR}')
    f1['restore_fs'] = sh(f'cat {FS_ATTR}')[1].decode().strip()
res['F1'] = f1

os.makedirs(f'{HERE}/results', exist_ok=True)
json.dump(res, open(f'{HERE}/results/{LABEL}.json', 'w'), indent=1)
print(json.dumps(res, indent=1))
