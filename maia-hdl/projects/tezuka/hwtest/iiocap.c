/* iiocap: zero-copy CS12 capture check with libiio.
 * The DMA blocks are used in place (libiio local backend, mmap); nothing is copied or written.
 * Usage: iiocap <block_bytes> <nblocks> <total_MB> [mode]
 *   mode: scan (default) = find sync magic + counter in place
 *         none = refill only (DMA path throughput, data not touched)
 *         copy = memcpy each block to a private buffer, then scan (what a copying reader costs)
 *         predict = read only the 24 bytes where the next sync must be; full scan of a block only
 *                   when it is not there (shows whether the DMA path itself loses data)
 * Reports bytes, MB/s, syncs, counter span and lost frames (from the sync counter). */
#include <iio.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <time.h>

static const uint8_t MAGIC[20] = {0xA1,0x5C,0x1E,0xAB,0xD2,0xC5,0xEF,0x12,0x37,0x9A,
                                  0x4D,0x6B,0xE1,0xF0,0x8A,0x3C,0x56,0x7D,0x91,0x24};
#define PERIOD 786432LL

struct st { long long syncs, regular, odd, c0, clast, jumps, missing, last; };

static void hit(struct st *s, long long pos, const uint8_t *p)
{
    long long c = p[20] | p[21] << 8 | p[22] << 16 | (long long)p[23] << 24;
    if (s->last >= 0) {
        if (pos - s->last == PERIOD) s->regular++; else s->odd++;
    }
    if (s->c0 < 0) s->c0 = c;
    else if (c != s->clast + 1) { s->jumps++; s->missing += c - s->clast - 1; }
    s->clast = c; s->last = pos; s->syncs++;
}

/* scan data[0..n) whose first byte is at absolute stream position base */
static void scan(struct st *s, const uint8_t *data, size_t n, long long base)
{
    size_t i = 0;
    while (n >= 24 && i + 24 <= n) {
        const uint8_t *q = memchr(data + i, 0xA1, n - 23 - i);
        if (!q) break;
        i = q - data;
        if (!memcmp(data + i, MAGIC, 20)) hit(s, base + i, data + i);
        i++;
    }
}

int main(int argc, char **argv)
{
    if (argc < 4) { fprintf(stderr, "usage: iiocap block_bytes nblocks total_MB [scan|none|copy]\n"); return 2; }
    size_t bb = strtoul(argv[1], 0, 0);
    unsigned nb = atoi(argv[2]);
    long long want = atoll(argv[3]) * 1000000LL;
    const char *mode = argc > 4 ? argv[4] : "scan";

    struct iio_context *ctx = iio_create_local_context();
    struct iio_device *dev = ctx ? iio_context_find_device(ctx, "cf-ad9361-lpc") : NULL;
    if (!dev) { fprintf(stderr, "no cf-ad9361-lpc\n"); return 1; }
    for (unsigned k = 0; k < iio_device_get_channels_count(dev); k++)
        iio_channel_disable(iio_device_get_channel(dev, k));
    struct iio_channel *ch = iio_device_find_channel(dev, "voltage1", false);
    if (!ch) { fprintf(stderr, "no voltage1\n"); return 1; }
    iio_channel_enable(ch);
    ssize_t ss = iio_device_get_sample_size(dev);
    if (iio_device_set_kernel_buffers_count(dev, nb)) fprintf(stderr, "set_kernel_buffers_count failed\n");
    struct iio_buffer *buf = iio_device_create_buffer(dev, bb / ss, false);
    if (!buf) { perror("create_buffer"); return 1; }

    uint8_t *priv = !strcmp(mode, "copy") ? malloc(bb) : NULL;
    uint8_t carry[48]; size_t ncarry = 0;
    struct st s = {0, 0, 0, -1, -1, 0, 0, -1};
    long long total = 0;
    struct timespec t0, t1;
    clock_gettime(CLOCK_MONOTONIC, &t0);
    while (total < want) {
        ssize_t n = iio_buffer_refill(buf);
        if (n < 0) { fprintf(stderr, "refill error %zd\n", n); break; }
        uint8_t *p = iio_buffer_start(buf);
        size_t len = (uint8_t *)iio_buffer_end(buf) - p;
        if (!strcmp(mode, "predict")) {
            /* in a complete stream the next sync is exactly PERIOD bytes after the last one */
            int resync = s.last < 0, carry_hit = 0;
            long long exp = s.last + PERIOD;
            if (ncarry)
                memcpy(carry + ncarry, p, 23);
            if (!resync && exp < total) {
                /* the expected sync starts in the last bytes of the previous block */
                if (exp >= total - (long long)ncarry) {
                    uint8_t *q = carry + (exp - (total - ncarry));
                    if (!memcmp(q, MAGIC, 20)) { hit(&s, exp, q); exp += PERIOD; carry_hit = 1; } else resync = 1;
                } else
                    resync = 1;
            }
            while (!resync && exp + 24 <= total + (long long)len) {
                if (!memcmp(p + (exp - total), MAGIC, 20)) { hit(&s, exp, p + (exp - total)); exp += PERIOD; }
                else resync = 1;
            }
            if (resync) {
                if (s.last >= 0) s.odd++;   /* data lost: the gap across it is not measured */
                s.last = -1;
                if (ncarry && !carry_hit)
                    scan(&s, carry, ncarry + 23, total - ncarry);
                scan(&s, p, len, total);
            }
            ncarry = len >= 23 ? 23 : len;
            memcpy(carry, p + len - ncarry, ncarry);
        } else if (strcmp(mode, "none")) {
            if (priv) { memcpy(priv, p, len); p = priv; }
            /* syncs straddling the block boundary: last 23 bytes of the previous block + first 23 here */
            if (ncarry) {
                memcpy(carry + ncarry, p, 23);
                scan(&s, carry, ncarry + 23, total - ncarry);
            }
            scan(&s, p, len, total);
            ncarry = len >= 23 ? 23 : len;
            memcpy(carry, p + len - ncarry, ncarry);
        }
        total += len;
    }
    clock_gettime(CLOCK_MONOTONIC, &t1);
    double sec = (t1.tv_sec - t0.tv_sec) + (t1.tv_nsec - t0.tv_nsec) / 1e9;
    printf("mode=%s block=%zu nblocks=%u bytes=%lld seconds=%.2f MBps=%.1f syncs=%lld regular=%lld odd=%lld "
           "counter_span=%lld jumps=%lld frames_missing=%lld\n", mode, bb, nb, total, sec, total / sec / 1e6,
           s.syncs, s.regular, s.odd, s.clast - s.c0, s.jumps, s.missing);
    iio_buffer_destroy(buf);
    iio_context_destroy(ctx);
    return 0;
}
