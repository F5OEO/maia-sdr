#
# Copyright (C) 2024 Daniel Estevez <daniel@destevez.net>
#
# This file is part of maia-sdr
#
# SPDX-License-Identifier: MIT
#

class MaiaSDRConfig:
    """Maia SDR configuration

    This class defines configuration parameters for the Maia SDR top-level.
    """
    def __init__(self):
        # create default configuration

        # general
        self.platform = 0

        # spectrometer
        self.spectrometer_address = 0x1a00_0000
        self.spectrometer_buffers = 8

        # IQ recorder
        self.recorder_address_range = (0x0100_0000, 0x1a00_0000)

        # Raw complex FFT capture (single-shot, tapped before the
        # spectrum integrator discards phase). 1 MiB default: enough for
        # several single-frame captures (one 4096-bin frame is 16 KiB
        # packed as 16-bit I/Q). Placed well clear of the spectrometer's
        # own buffers (spectrometer_address + spectrometer_buffers *
        # 2**12 entries * 8 bytes/entry), but overlap with spectrometer
        # or recorder is not checked -- see the TODO below.
        self.raw_capture_address_range = (0x1a10_0000, 0x1a20_0000)

        # Continuous low-rate complex (I/Q) output, latched once per
        # integration epoch (same cadence as the magnitude waterfall) and
        # DMA'd out like a second small waterfall -- see Spectrometer's
        # iq_dma. 128 KiB: spectrometer_buffers (8) * 2**12 entries *
        # 4 bytes/entry (16-bit I + 16-bit Q, half the magnitude DMA's
        # 8 bytes/entry). Placed right after raw_capture_address_range.
        self.iq_waterfall_address_range = (0x1a20_0000, 0x1a22_0000)

    def spectrometer_address_range(self):
        size = self.spectrometer_buffers * 2**12 * 8
        return (self.spectrometer_address, self.spectrometer_address + size)

    def validate(self):
        assert self.platform >= 0 and self.platform < 256
        assert self.spectrometer_buffers > 0
        assert self.spectrometer_buffers.bit_count() == 1
        assert self.recorder_address_range[0] < self.recorder_address_range[1]
        assert (self.raw_capture_address_range[0]
                < self.raw_capture_address_range[1])
        assert (self.iq_waterfall_address_range[0]
                < self.iq_waterfall_address_range[1])

        ranges = [
            ('spectrometer', self.spectrometer_address_range()),
            ('recorder', self.recorder_address_range),
            ('raw_capture', self.raw_capture_address_range),
            ('iq_waterfall', self.iq_waterfall_address_range),
        ]
        for j, (name_a, (start_a, end_a)) in enumerate(ranges):
            for name_b, (start_b, end_b) in ranges[j + 1:]:
                assert start_a >= end_b or start_b >= end_a, (
                    f'{name_a} address range overlaps with {name_b}')
