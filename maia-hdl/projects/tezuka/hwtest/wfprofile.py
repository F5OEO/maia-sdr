"""Read N /waterfall frames and report the fastlock profile (f[0]) sequence."""
import asyncio, struct, sys, time, json
import websockets

async def main(host, n):
    seq, ts = [], []
    async with websockets.connect(f'ws://{host}/waterfall', max_size=None) as ws:
        while len(seq) < n:
            m = await ws.recv()
            if isinstance(m, bytes) and len(m) >= 4:
                seq.append(int(struct.unpack_from('<f', m, 0)[0]))
                ts.append(time.monotonic())
    steps = [(b - a) % 8 for a, b in zip(seq, seq[1:])]
    period = (ts[-1] - ts[0]) / (len(ts) - 1)
    print(json.dumps({'frames': len(seq), 'frame_period_s': round(period, 4),
                      'profiles_seen': sorted(set(seq)), 'first_32': seq[:32],
                      'step_histogram': {s: steps.count(s) for s in sorted(set(steps))}}))

asyncio.run(main(sys.argv[1], int(sys.argv[2]) if len(sys.argv) > 2 else 64))
