/* gapcheck: read a CS12 stream on stdin, find the sync magic and report gaps.
 * Usage: iio_readdev ... | gapcheck [period_bytes]
 * Prints total bytes, sync count, how many gaps differ from the period, and the first few odd gaps. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <time.h>
#include <unistd.h>

static const uint8_t MAGIC[20] = {0xA1,0x5C,0x1E,0xAB,0xD2,0xC5,0xEF,0x12,0x37,0x9A,
                                  0x4D,0x6B,0xE1,0xF0,0x8A,0x3C,0x56,0x7D,0x91,0x24};

int main(int argc, char **argv)
{
    long long period = argc > 1 ? atoll(argv[1]) : 786432;
    static uint8_t buf[(1 << 20) + 32];
    size_t keep = 0;
    long long base = 0, last = -1, total = 0, syncs = 0, regular = 0, odd = 0;
    long long oddv[16]; int nodd = 0;
    long long c0 = -1, clast = -1, cjumps = 0, cmissing = 0;
    struct timespec t0, t1;
    clock_gettime(CLOCK_MONOTONIC, &t0);
    for (;;) {
        ssize_t n = read(0, buf + keep, sizeof(buf) - 32 - keep);
        if (n <= 0)
            break;
        total += n;
        size_t len = keep + n;
        for (size_t i = 0; i + 24 <= len; i++) {
            uint8_t *q = memchr(buf + i, 0xA1, len - 23 - i);
            if (!q)
                break;
            i = q - buf;
            if (memcmp(buf + i, MAGIC, 20))
                continue;
            long long pos = base + i;
            if (last >= 0) {
                long long g = pos - last;
                if (g == period)
                    regular++;
                else {
                    odd++;
                    if (nodd < 16)
                        oddv[nodd++] = g;
                }
            }
            last = pos;
            syncs++;
            long long c = buf[i + 20] | buf[i + 21] << 8 | buf[i + 22] << 16 | (long long)buf[i + 23] << 24;
            if (c0 < 0)
                c0 = c;
            else if (c != clast + 1) {
                cjumps++;
                cmissing += c - clast - 1;
            }
            clast = c;
        }
        keep = len < 23 ? len : 23;
        memmove(buf, buf + len - keep, keep);
        base += len - keep;
    }
    clock_gettime(CLOCK_MONOTONIC, &t1);
    double s = (t1.tv_sec - t0.tv_sec) + (t1.tv_nsec - t0.tv_nsec) / 1e9;
    printf("bytes=%lld seconds=%.2f MBps=%.1f syncs=%lld regular=%lld odd=%lld counter_span=%lld counter_jumps=%lld frames_missing=%lld",
           total, s, total / s / 1e6, syncs, regular, odd, clast - c0, cjumps, cmissing);
    for (int k = 0; k < nodd; k++)
        printf("%s%lld", k ? "," : " odd_gaps=", oddv[k]);
    printf("\n");
    return 0;
}
