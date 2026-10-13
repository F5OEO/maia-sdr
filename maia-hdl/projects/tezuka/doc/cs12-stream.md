# CS12 stream format

CS12 packs each I/Q sample as two 12-bit values, so the stream carries 3 bytes per sample instead of 4. It is
produced by `projects/common/cs12_cs8mux.v` (packing) and `projects/common/cs12_sync_frame.v` (sync bursts) and
read through the normal `cf-ad9361-lpc` IIO device. This page is the contract a host decoder needs.

## Selecting CS12

The channel enables of `cf-ad9361-lpc` select the format:

| Enabled channels | Format |
|---|---|
| voltage0 and voltage1 | CS16 (standard IIO, unchanged) |
| voltage0 only | CS8 |
| voltage1 only | CS12 |

In CS12 the IIO buffer of `voltage1` is just a byte stream: read it as bytes, not as 16-bit samples. The byte
rate is 3 x the sample rate (184.32 MB/s at 61.44 MS/s).

## Bursts

The stream is a sequence of 24-byte bursts. Each burst holds 8 consecutive samples, oldest first:

- bytes `4c+0, 4c+1` for c = 0..5 are the I bits, bytes `4c+2, 4c+3` the Q bits;
- the 12 I bytes, concatenated in order, form one 96-bit big-endian number. Sample k (k = 0..7, 0 is the oldest)
  is bits `95-12k .. 84-12k`, a 12-bit two's-complement value. The same holds for the 12 Q bytes.

```python
def unpack_burst(b):                       # b: 24 bytes -> 8 complex samples
    i96 = int.from_bytes(bytes(b[4 * c + k] for c in range(6) for k in (0, 1)), 'big')
    q96 = int.from_bytes(bytes(b[4 * c + k] for c in range(6) for k in (2, 3)), 'big')
    def s12(v): return v - 4096 if v & 0x800 else v
    return [complex(s12(i96 >> (84 - 12 * k) & 0xFFF), s12(q96 >> (84 - 12 * k) & 0xFFF)) for k in range(8)]
```

Full scale is -2048..2047, the same scale as CS16 (which carries the 12-bit ADC value sign-extended).

## Sync bursts

Every `SYNC_PERIOD_SAMPLES` sample slots (262144 in the current builds, a synthesis parameter of
`cs12_sync_frame`), one burst is a sync burst instead of data:

```
A1 5C 1E AB D2 C5 EF 12 37 9A 4D 6B E1 F0 8A 3C 56 7D 91 24  <counter: uint32, little endian>
```

- **It replaces 8 samples; it is not inserted.** The sample after the sync burst is 9 sample periods after the
  sample before it. Those 8 samples are lost, so the stream has a gap of 8 samples every period (every 4.3 ms at
  61.44 MS/s, a 234 Hz repetition). A decoder must not decode the sync burst as samples. Blank the 8 slots
  (write zeros, or interpolate) when timing or spectral purity matters, or drop them when it does not.
- **Finding the period:** there is no register for it. Measure it from the stream: the distance between two
  consecutive MAGICs is `SYNC_PERIOD_SAMPLES * 3` bytes (786432 bytes for 262144). Do not hard-code it.
- **Alignment:** a MAGIC always starts a burst, so after the first MAGIC the 24-byte burst grid is known.
  Discard the bytes before the first MAGIC.
- **Loss detection:** the counter increases by 1 per sync burst and wraps at 2^32. A step of n > 1 means
  n - 1 whole periods were lost; a MAGIC that is not one period after the previous one means bytes were lost
  inside a period, and the decoder should re-align on it.

CS8 and CS16 have no sync bursts.

## Checked on hardware

`hwtest/cs12layout.py` captures the AD9363 BIST tone at fs/32 in CS12 on a Pluto+ and decodes it with the
code above. Result (2.5 MS/s, 4 periods): MAGIC every 786432 bytes, counter steps of 1, a clean tone at
amplitude 1024 (BIST at -6 dB, relative fit residual 0.0007) in every period, and a phase step of exactly
9 sample periods across each of the sync bursts (an inserted burst would give 1).
