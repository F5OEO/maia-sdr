"""F2 test: AD9363 BIST tone -> maia DDC -> CS16 capture with DDC routing on.

Looks for single-sample I/Q misalignment (Q taken one sample stale/early)
caused by
I and Q crossing clock domains in separate FIFOs.
Usage: [FS=61440000] [BIST_LEVEL_DB=6] tonetest.py <label> [host] [seconds]
-> results/<label>-tone.json
       tonetest.py --selftest <capture.npy>   (plants Q slips in a saved
       capture, checks they are found)
The tone is BIST mode 2 (injected into RX) at fs/32; the DDC is tuned 100
kHz below it, so a
correct I/Q order gives +100 kHz. 0 dB overdrives the DDC (see F18), hence
the 6 dB default.
"""
import json
import os
import subprocess
import sys
import time
import numpy as np

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
    'root@192.168.4.1']
HOST = '192.168.4.1'   # both replaced in main()
DBG = '/sys/kernel/debug/iio/iio:device0'
PHY = '/sys/bus/iio/devices/iio:device0'


def sh(cmd, timeout=120):
    return subprocess.run(
        SSH + [cmd],
        capture_output=True,
        timeout=timeout).stdout


def api(patch):
    r = subprocess.run(['curl',
                        '-s',
                        '-X',
                        'PATCH',
                        '-H',
                        'Content-Type: application/json',
                        '-d',
                        json.dumps(patch),
                        f'http://{HOST}/api/ddc/config'],
                       capture_output=True,
                       text=True,
                       timeout=20)
    return json.loads(subprocess.run(['curl',
                                      '-s',
                                      f'http://{HOST}/api/ddc/config'],
                                     capture_output=True,
                                     text=True).stdout)


def _interp(z, taps=8, coef=None):
    """Two-sided least-squares interpolator: estimate z[n] from z[n-taps..n-1]
    and z[n+1..n+taps]."""
    n = len(z)
    cols = ([z[taps - m:n - taps - m] for m in range(1, taps + 1)]
            + [z[taps + m:n - taps + m] for m in range(1, taps + 1)])
    A = np.stack(cols, axis=1)
    y = z[taps:n - taps]
    if coef is None:
        coef = np.linalg.lstsq(A, y, rcond=None)[0]
    est = np.full(n, np.nan + 0j)
    est[taps:n - taps] = A @ coef
    return est, coef


def classify(z, thr_sigma=10.0, taps=8):
    """Find samples where I or Q does not fit the signal and classify them.

    A sum of a few complex tones is predicted almost exactly by a two-sided
    linear interpolator, so
    e[n] = z[n] - est[n] is quantisation noise for clean data. For each
    outlier sample k the I and Q
    errors are compared: a stale/early Q gives a large Q error, a small I
    error, and Q[k] equal to
    Q[k-1] (lag) or Q[k+1] (lead). A dropout disturbs several samples and
    both components.
    """
    n = len(z)
    # coefficients are global; outliers are rare enough not to bias them
    est, coef = _interp(z, taps)
    e = z - est
    ei, eq = np.abs(e.real), np.abs(e.imag)
    si = 1.4826 * np.nanmedian(ei) + 0.5
    sq = 1.4826 * np.nanmedian(eq) + 0.5
    thr_i, thr_q = thr_sigma * si, thr_sigma * sq
    bad = np.where((ei > thr_i) | (eq > thr_q))[0]
    # an outlier also disturbs the estimates of its neighbours; keep the local
    # maxima
    events, i = [], 0
    while i < len(bad):
        j = i
        while j + 1 < len(bad) and bad[j + 1] - bad[j] <= taps:
            j += 1
        grp = bad[i:j + 1]
        events.append(
            (int(grp[np.argmax(np.abs(e[grp]))]), int(grp[0]), int(grp[-1])))
        i = j + 1
    kinds = {
        'q_lag': 0,
        'q_lead': 0,
        'i_lag': 0,
        'i_lead': 0,
        'dropout': 0,
        'other': 0}
    where = []
    I, Q = z.real, z.imag
    for k, g0, g1 in events:
        if k < 2 * taps or k + 2 * taps >= n:
            continue
        q_off, i_off = eq[k] > thr_q, ei[k] > thr_i
        n_strong = int(np.sum((ei[g0:g1 + 1] > thr_i)
                       | (eq[g0:g1 + 1] > thr_q)))
        if q_off and not i_off and Q[k] == Q[k - 1]:
            kind = 'q_lag'
        elif q_off and not i_off and Q[k] == Q[k + 1]:
            kind = 'q_lead'
        elif i_off and not q_off and I[k] == I[k - 1]:
            kind = 'i_lag'
        elif i_off and not q_off and I[k] == I[k + 1]:
            kind = 'i_lead'
        elif n_strong > 3:
            kind = 'dropout'
        else:
            kind = 'other'
        kinds[kind] += 1
        where.append(
            (k, kind, round(
                float(
                    e[k].real), 1), round(
                float(
                    e[k].imag), 1)))
    # fraction of samples where a one-sample Q slip would be visible above the
    # threshold
    detectable = float(np.mean(np.abs(np.diff(Q)) > thr_q))
    return {'samples': n,
            'amp': round(float(np.median(np.abs(z))),
                         1),
            'noise_lsb_i_q': [round(si,
                                    2),
                              round(sq,
                                    2)],
            'thr_lsb_q': round(thr_q,
                               1),
            'q_slip_detectable_fraction': round(detectable,
                                                3),
            'events': len(events),
            **kinds,
            'where': where[:50]}


def main(label, host, seconds):
    global SSH, HOST
    HOST = host
    SSH = SSH[:-1] + [f'root@{host}']
    os.makedirs(f'{HERE}/results', exist_ok=True)
    FS = os.environ.get('FS')
    fs_orig = sh(f'cat {PHY}/in_voltage_sampling_frequency').decode().strip()
    if FS:
        sh(f'echo {FS} > {PHY}/in_voltage_sampling_frequency')
        time.sleep(2)
    fs = int(sh(f'cat {PHY}/in_voltage_sampling_frequency').decode())
    tone = fs // 32                                   # BIST tone index 0
    # tone attenuation in dB (multiples of 6)
    LEVEL = int(os.environ.get("BIST_LEVEL_DB", "6"))
    # mode 2 = inject into RX
    sh(f'echo "2 {tone} {LEVEL} 0" > {DBG}/bist_tone')
    cfg = api({'frequency': float(tone - 100000), 'enabled': True})
    fout = cfg['output_sampling_frequency']
    reg = sh('devmem 0x790200BC 32').decode().strip()

    chunks, per = [], int(fout)                       # 1 s per capture
    for i in range(int(seconds)):
        sh(f'iio_readdev -b 262144 -s {per} cf-ad9361-lpc '
           f'voltage0 voltage1 > /tmp/tone.bin', timeout=60)
        raw = sh('cat /tmp/tone.bin', timeout=120)
        chunks.append(np.frombuffer(raw, dtype='<i2').reshape(-1, 2))
    sh('rm -f /tmp/tone.bin')
    np.save(f'{HERE}/results/{label}-tone-first.npy', chunks[0])
    api({'enabled': False, 'frequency': 0.0})
    sh(f'echo "0 0 0 0" > {DBG}/bist_tone')
    if FS:
        sh(f'echo {fs_orig} > {PHY}/in_voltage_sampling_frequency')

    stats = {
        'fs': fs,
        'tone_hz': tone,
        'bist_level_db': LEVEL,
        'ddc_out': fout,
        'routing_reg': reg,
        'captures': []}
    tot = {
        'samples': 0,
        'q_lag': 0,
        'q_lead': 0,
        'i_lag': 0,
        'i_lead': 0,
        'dropout': 0,
        'other': 0}
    for c in chunks:
        z = c[:, 0].astype(float) + 1j * c[:, 1].astype(float)
        r = classify(z)
        dphi = float(np.median(np.angle(z[1:] * np.conj(z[:-1]))))
        r['tone_offset_hz'] = round(dphi * fout / (2 * np.pi), 1)
        # a capture only counts if the tone is there; otherwise a slip could
        # not be seen
        r['valid'] = r['q_slip_detectable_fraction'] > 0.5 and abs(
            r['tone_offset_hz'] - 100000) < 1000
        stats['captures'].append(r)
        if not r['valid']:
            continue
        tot['samples'] += r['samples']
        for k in tot:
            if k != 'samples':
                tot[k] += r[k]
    stats['total'] = tot
    stats['invalid_captures'] = [
        i for i, c in enumerate(
            stats['captures']) if not c['valid']]
    glitch = tot['q_lag'] + tot['q_lead'] + tot['i_lag'] + tot['i_lead']
    stats['iq_misalign_per_million'] = round(
        glitch / tot['samples'] * 1e6,
        3) if tot['samples'] else None
    json.dump(stats, open(f'{HERE}/results/{label}-tone.json', 'w'), indent=1)
    print(json.dumps({k: stats[k] for k in ('fs',
                                            'tone_hz',
                                            'ddc_out',
                                            'routing_reg',
                                            'total',
                                            'iq_misalign_per_million',
                                            'invalid_captures')}))
    print('per capture (events, slips, other, dropouts, tone Hz):',
          [(c['events'],
            c['q_lag'] + c['q_lead'] + c['i_lag'] + c['i_lead'],
              c['other'],
              c['dropout'],
              c['tone_offset_hz']) for c in stats['captures']][:8])


def selftest(path, n=200, seed=1):
    """Plant n single-sample Q lags (Q[k] = Q[k-1]) and n Q leads in a clean
    capture."""
    c = np.load(path)
    z0 = c[:, 0].astype(float) + 1j * c[:, 1].astype(float)
    base = classify(z0)
    rng = np.random.default_rng(seed)
    ks = rng.choice(np.arange(100, len(z0) - 100, 50), 2 * n, replace=False)
    z = z0.copy()
    for k in ks[:n]:
        z[k] = z[k].real + 1j * z[k - 1].imag
    for k in ks[n:]:
        z[k] = z[k].real + 1j * z[k + 1].imag
    r = classify(z)
    # a planted slip is only visible where Q actually changes between
    # neighbours
    vis_lag = sum(abs(z0[k].imag - z0[k - 1].imag)
                  > r['thr_lsb_q'] for k in ks[:n])
    vis_lead = sum(abs(z0[k].imag - z0[k + 1].imag)
                   > r['thr_lsb_q'] for k in ks[n:])
    print(
        json.dumps(
            {
                'baseline': {
                    k: base[k] for k in (
                        'q_lag',
                        'q_lead',
                        'other')},
                'planted': {
                    'q_lag': n,
                    'q_lead': n},
                'visible': {
                    'q_lag': int(vis_lag),
                    'q_lead': int(vis_lead)},
                'found': {
                    k: r[k] -
                    base[k] for k in (
                        'q_lag',
                        'q_lead',
                        'i_lag',
                        'i_lead',
                        'other')}}))


if __name__ == '__main__':
    if len(sys.argv) > 2 and sys.argv[1] == '--selftest':
        selftest(sys.argv[2])
    else:
        main(sys.argv[1] if len(sys.argv) > 1 else 'run',
             sys.argv[2] if len(sys.argv) > 2 else '192.168.4.1',
             float(sys.argv[3]) if len(sys.argv) > 3 else 20)
