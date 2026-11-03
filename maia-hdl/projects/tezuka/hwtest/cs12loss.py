"""CS12 capture-loss probe: how often does iio_readdev lose sync periods?

Captures (PERIODS + 1) sync periods of CS12 (only voltage1 enabled, DDC
routing off) with iio_readdev on the board, once per repetition and buffer
size, writing to /tmp like cs12layout.py. A capture is clean when every
sync burst is 786432 bytes after the previous one and the counter steps by 1.
Usage: cs12loss.py <host> <captures> <periods> <buffer_samples> [...]
"""
import subprocess
import sys

HOST = sys.argv[1]
N = int(sys.argv[2])
PERIODS = int(sys.argv[3])
BUFS = [int(b) for b in sys.argv[4:]]
MAGIC = bytes.fromhex('A15C1EABD2C5EF12379A4D6BE1F08A3C567D9124')
PERIOD = 786432
SSH = ['sshpass', '-p', 'analog', 'ssh', '-o', 'StrictHostKeyChecking=no',
       '-o', 'UserKnownHostsFile=/dev/null', '-o', 'LogLevel=ERROR',
       f'root@{HOST}']


def sh(cmd, timeout=120):
    return subprocess.run(SSH + [cmd], capture_output=True,
                          timeout=timeout).stdout


def analyse(raw):
    pos, i = [], raw.find(MAGIC)
    while i >= 0:
        pos.append(i)
        i = raw.find(MAGIC, i + 1)
    odd = sum(1 for a, b in zip(pos, pos[1:]) if b - a != PERIOD)
    ctr = [int.from_bytes(raw[p + 20:p + 24], 'little') for p in pos]
    jumps = sum(1 for a, b in zip(ctr, ctr[1:]) if b != a + 1)
    return len(pos), odd, jumps


nsamp = (PERIODS + 1) * PERIOD // 2
for buf in BUFS:
    clean = 0
    detail = []
    for _ in range(N):
        raw = sh(f'iio_readdev -b {buf} -s {nsamp} cf-ad9361-lpc voltage1 '
                 f'> /tmp/c12.bin 2>/dev/null; cat /tmp/c12.bin; '
                 f'rm -f /tmp/c12.bin')
        syncs, odd, jumps = analyse(raw)
        clean += syncs >= PERIODS and odd == 0 and jumps == 0
        detail.append(f'{syncs}/{odd}/{jumps}')
    print(f'buffer {buf} samples ({buf * 2 // 1024} KiB): clean {clean}/{N}'
          f'   (syncs/odd-gaps/counter-jumps: {" ".join(detail)})',
          flush=True)
