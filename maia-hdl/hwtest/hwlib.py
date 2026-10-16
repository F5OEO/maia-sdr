"""Helpers shared by the Pluto/Pluto+ hardware tests of the raw capture and
the I/Q waterfall.

The tests use two boards connected by a cable with an attenuator (TX of the
transmit board into RX of the board under test) and talk to them over ssh
(radio settings, DDS/cyclic TX writer) and over the maia-httpd API
(/waterfall, /iq-waterfall, /api/raw-capture, /raw-capture).
"""
import asyncio
import subprocess
import time
import urllib.request

import numpy as np
import websockets

PHY = '/sys/bus/iio/devices/iio:device0'
ATTRS = [
    'out_altvoltage0_RX_LO_frequency', 'out_altvoltage1_TX_LO_frequency',
    'in_voltage0_gain_control_mode', 'in_voltage0_hardwaregain',
    'out_voltage0_hardwaregain', 'in_voltage_sampling_frequency',
    'in_voltage_rf_bandwidth', 'out_voltage_rf_bandwidth']
FRAME = 4096
TONE_PERIOD = 25000    # samples in the cyclic TX buffer


def ssh(host, cmd, timeout=60, stdin=None):
    r = subprocess.run(
        ['sshpass', '-p', 'analog', 'ssh', '-o', 'StrictHostKeyChecking=no',
         '-o', 'UserKnownHostsFile=/dev/null', '-o', 'LogLevel=ERROR',
         '-o', 'ConnectTimeout=5', f'root@{host}', cmd],
        capture_output=True, timeout=timeout, input=stdin)
    return r.stdout.decode().strip()


def save_settings(host):
    return {a: ssh(host, f'cat {PHY}/{a}').split()[0] for a in ATTRS}


def restore_settings(host, s):
    cmds = [
        'in_voltage_sampling_frequency', 'in_voltage_rf_bandwidth',
        'out_voltage_rf_bandwidth', 'out_altvoltage0_RX_LO_frequency',
        'out_altvoltage1_TX_LO_frequency', 'out_voltage0_hardwaregain',
        'in_voltage0_gain_control_mode']
    ssh(host, '; '.join(f'echo {s[a]} > {PHY}/{a}' for a in cmds))
    if s['in_voltage0_gain_control_mode'] == 'manual':
        ssh(host, f'echo {s["in_voltage0_hardwaregain"]} > '
                  f'{PHY}/in_voltage0_hardwaregain')


def configure(tx, rx, fs, bw, lo, rx_gain, tx_gain=0):
    for h in (tx, rx):
        ssh(h, f'echo {fs} > {PHY}/in_voltage_sampling_frequency; '
               f'echo {bw} > {PHY}/in_voltage_rf_bandwidth; '
               f'echo {bw} > {PHY}/out_voltage_rf_bandwidth')
    ssh(tx, f'echo {lo} > {PHY}/out_altvoltage1_TX_LO_frequency; '
            f'echo {tx_gain} > {PHY}/out_voltage0_hardwaregain')
    ssh(rx, f'echo {lo} > {PHY}/out_altvoltage0_RX_LO_frequency; '
            f'echo manual > {PHY}/in_voltage0_gain_control_mode; '
            f'echo {rx_gain} > {PHY}/in_voltage0_hardwaregain')
    rates = [int(ssh(h, f'cat {PHY}/in_voltage_sampling_frequency'))
             for h in (tx, rx)]
    assert rates == [fs, fs], f'sample rate not applied: {rates}'


def stop_tx(tx):
    ssh(tx, 'kill $(pidof iio_writedev) 2>/dev/null; sleep 1')


def start_tx(tx, x, rms):
    """Transmit the complex array x in a cyclic buffer, scaled to rms."""
    x = x / np.sqrt(np.mean(np.abs(x) ** 2)) * rms
    assert np.abs(x).max() < 30000, 'clipping'
    iq = np.empty(2 * len(x), '<i2')
    iq[0::2] = np.round(x.real)
    iq[1::2] = np.round(x.imag)
    stop_tx(tx)
    ssh(tx, 'cat > /tmp/rf_tx.bin', stdin=iq.tobytes())
    ssh(tx, f"printf '%s\\n' 'iio_writedev -c -b {len(x)} "
            "cf-ad9361-dds-core-lpc voltage0 voltage1 < /tmp/rf_tx.bin "
            "> /tmp/rf_tx.log 2>&1 &' > /tmp/rf_tx.sh; sh /tmp/rf_tx.sh")
    time.sleep(2.5)
    dds = ssh(tx, 'for d in /sys/bus/iio/devices/iio:device*; do '
                  'grep -q dds-core $d/name && echo $d; done')
    st = ssh(tx, f'echo writers $(pidof iio_writedev | wc -w) '
                 f'buffer $(cat {dds}/buffer/enable)')
    assert st.startswith('writers 1 buffer 1'), st


def tx_cleanup(tx):
    stop_tx(tx)
    ssh(tx, 'rm -f /tmp/rf_tx.bin /tmp/rf_tx.sh /tmp/rf_tx.log')


def tone(fs, freq, n=TONE_PERIOD):
    return np.exp(2j * np.pi * freq * np.arange(n) / fs)


def tone_freq(fs, k):
    """Frequency of the tone with k periods in the TX buffer: it repeats
    seamlessly, so the cyclic buffer has no phase jump."""
    return k * fs / TONE_PERIOD


def ofdm(nsym, n, g, n_active, rng):
    """CP-OFDM, random QPSK on n_active carriers around DC (DC unused)."""
    ks = np.r_[1:n_active // 2 + 1, n - n_active // 2:n]
    out = []
    for _ in range(nsym):
        x_f = np.zeros(n, complex)
        x_f[ks] = (rng.choice([-1, 1], len(ks))
                   + 1j * rng.choice([-1, 1], len(ks))) / np.sqrt(2)
        x = np.fft.ifft(x_f) * np.sqrt(n)
        out.append(np.concatenate([x[-g:], x]))
    return np.concatenate(out)


def http(host, method, path, body=None):
    req = urllib.request.Request(
        f'http://{host}{path}', data=body, method=method,
        headers={'Content-Type': 'application/json'})
    return urllib.request.urlopen(req, timeout=20).read()


async def grab_ws(host, path, secs):
    """Binary 16384-byte messages (4096 bins x 4 bytes) of a websocket."""
    out = []
    async with websockets.connect(f'ws://{host}/{path}',
                                  max_size=None) as ws:
        end = time.monotonic() + secs
        while time.monotonic() < end:
            m = await asyncio.wait_for(ws.recv(), 10)
            if isinstance(m, bytes) and len(m) == 4 * FRAME:
                out.append(m)
    return out


def iq_words(frames):
    """/iq-waterfall messages -> complex array (frames, bins). Each word is
    I in the high 16 bits and Q in the low 16 bits (signed)."""
    u = np.array([np.frombuffer(m, '<u4') for m in frames])
    i = (u >> 16).astype(np.uint16).view(np.int16).astype(float)
    q = (u & 0xffff).astype(np.uint16).view(np.int16).astype(float)
    return i + 1j * q


def mag_frames(frames):
    return np.array([np.frombuffer(m, '<f4') for m in frames])


def raw_capture(host):
    """Single-shot raw capture: 64 frames of 4096 complex FFT outputs, in
    bit-reversed bin order starting at an arbitrary position of a frame."""
    http(host, 'PATCH', '/api/raw-capture', b'{"state_change":"Start"}')
    time.sleep(3)
    raw = np.frombuffer(http(host, 'GET', '/raw-capture'),
                        '<i2').reshape(-1, 2).astype(float)
    return raw[:, 0] + 1j * raw[:, 1]


def bitrev(n=FRAME):
    bits = n.bit_length() - 1
    return np.array([int(format(i, f'0{bits}b')[::-1], 2) for i in range(n)])


def td_capture(host, n=1 << 18):
    """Time-domain samples through libiio (needs iio_readdev on the host).
    One buffer only: libiio over Ethernet is not continuous above about
    12 MS/s."""
    raw = subprocess.run(
        ['iio_readdev', '-u', f'ip:{host}', '-b', str(n), '-s', str(n),
         'cf-ad9361-lpc', 'voltage0', 'voltage1'],
        capture_output=True, timeout=60).stdout
    d = np.frombuffer(raw, '<i2').reshape(-1, 2).astype(float)
    return d[:, 0] + 1j * d[:, 1]


def td_freq(y, fs):
    """Frequency of the strongest tone, interpolated on a zero-padded FFT."""
    y = y - y.mean()
    n = len(y)
    spec = np.abs(np.fft.fft(y * np.blackman(n), 4 * n))
    k = int(spec.argmax())
    a, b, c = np.log(spec[k - 1:k + 2])
    f = (k + 0.5 * (a - c) / (a - 2 * b + c)) / (4 * n) * fs
    return f if f < fs / 2 else f - fs
