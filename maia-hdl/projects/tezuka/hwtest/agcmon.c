/* agcmon: sample the Zynq EMIO GPIO pad values (bank 2 DATA_RO) and report
 * activity on EN_AGC (EMIO 12 = gpio 66) and CTRL_IN1..3 (EMIO 9..11).
 * gpio_i[13:0] on Pluto/Pluto+ is the ad_iobuf pad readback, so this sees what
 * the AD9363 pin actually gets.  Usage: agcmon <seconds> */
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>

static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec + t.tv_nsec * 1e-9; }

int main(int argc, char **argv)
{
	double dur = argc > 1 ? atof(argv[1]) : 10.0;
	int fd = open("/dev/mem", O_RDONLY | O_SYNC);
	if (fd < 0) { perror("/dev/mem"); return 1; }
	volatile uint32_t *g = mmap(NULL, 0x1000, PROT_READ, MAP_SHARED, fd, 0xE000A000);
	if (g == MAP_FAILED) { perror("mmap"); return 1; }
	uint32_t dirm = g[0x284 / 4], oen = g[0x288 / 4];
	printf("bank2 DIRM=0x%08x OEN=0x%08x  EN_AGC(bit12) dir=%s oe=%d\n", dirm, oen,
	       (dirm >> 12) & 1 ? "out" : "in", (oen >> 12) & 1);
	unsigned long n = 0, hi12 = 0, rise12 = 0, rise_ctl = 0, ctl_hist[8] = {0};
	uint32_t prev = g[0x68 / 4], ctl_seen = 0;
	double t0 = now(), first_rise = -1, last_rise = -1;
	while (now() - t0 < dur) {
		uint32_t v = g[0x68 / 4];
		n++;
		if (v & (1u << 12)) hi12++;
		if ((v & ~prev) & (1u << 12)) { rise12++; last_rise = now() - t0; if (first_rise < 0) first_rise = last_rise; }
		if ((v ^ prev) & (7u << 9)) rise_ctl++;
		ctl_seen |= v & (7u << 9);
		ctl_hist[(v >> 9) & 7]++;
		prev = v;
	}
	printf("samples=%lu duration=%.1fs\n", n, dur);
	printf("EN_AGC: rising_edges=%lu high_fraction=%.4f first_rise=%.3fs last_rise=%.3fs\n",
	       rise12, n ? (double)hi12 / n : 0, first_rise, last_rise);
	printf("CTRL_IN1..3 pad: transitions=%lu bits_seen=0x%x histogram:", rise_ctl, ctl_seen >> 9);
	for (int i = 0; i < 8; i++) printf(" %d:%.3f", i, n ? (double)ctl_hist[i] / n : 0);
	printf("\n");
	return 0;
}
