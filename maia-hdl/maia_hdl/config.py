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

    def validate(self):
        assert self.platform >= 0 and self.platform < 256
        assert self.spectrometer_buffers > 0
        assert self.spectrometer_buffers.bit_count() == 1
        assert self.recorder_address_range[0] < self.recorder_address_range[1]
        assert (self.raw_capture_address_range[0]
                < self.raw_capture_address_range[1])
        # TODO: check that spectrometer, recorder and raw_capture buffers
        # do not overlap
