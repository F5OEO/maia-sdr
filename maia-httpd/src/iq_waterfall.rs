//! Continuous I/Q waterfall channel.
//!
//! This module is used for the continuous, low-rate complex (I/Q) output of
//! the Maia SDR FPGA IP core: once per integration epoch (the same cadence
//! as the magnitude waterfall), the last FFT frame's complex bins are
//! latched and DMA'd out (see maia-hdl's `Spectrometer.iq_dma`). Modeled on
//! `spectrometer.rs`'s `Spectrometer` struct, but simpler: unlike the
//! magnitude waterfall, this data is not floating-point mantissa+exponent
//! encoded -- the FPGA already packs plain 16-bit I and 16-bit Q per
//! sample, so the raw buffer bytes are exactly the wire format this is
//! streamed to the browser in (no decode, no scale factor).

use crate::{app::AppState, fpga::InterruptWaiter};
use anyhow::Result;
use bytes::Bytes;
use tokio::sync::broadcast;

/// Continuous I/Q waterfall channel.
///
/// This struct waits for interrupts from the I/Q waterfall channel in the
/// FPGA IP core, and sends the raw buffer data (serialized into [`Bytes`])
/// into a [`tokio::sync::broadcast::Sender`].
#[derive(Debug)]
pub struct IqWaterfall {
    state: AppState,
    sender: broadcast::Sender<Bytes>,
    interrupt: InterruptWaiter,
}

impl IqWaterfall {
    /// Creates a new I/Q waterfall struct.
    ///
    /// The `interrupt` parameter should correspond to the [`InterruptWaiter`]
    /// corresponding to the I/Q waterfall channel. Each buffer received from
    /// the FPGA is sent to the `sender`.
    pub fn new(
        state: AppState,
        interrupt: InterruptWaiter,
        sender: broadcast::Sender<Bytes>,
    ) -> IqWaterfall {
        IqWaterfall {
            state,
            interrupt,
            sender,
        }
    }

    /// Runs the I/Q waterfall channel.
    ///
    /// This function only returns if there is an error. The function should
    /// be run concurrently with the rest of the application for the I/Q
    /// waterfall channel to work.
    #[tracing::instrument(name = "iq_waterfall", skip_all)]
    pub async fn run(self) -> Result<()> {
        loop {
            self.interrupt.wait().await;
            let mut ip_core = self.state.ip_core().lock().unwrap();
            tracing::trace!(last_buffer = ip_core.iq_waterfall_last_buffer());
            // TODO: potential optimization: do not hold the mutex locked
            // while we iterate over the buffers (same TODO as
            // spectrometer.rs's Spectrometer::run).
            for buffer in ip_core.get_iq_waterfall_buffers() {
                if self.sender.receiver_count() > 0 {
                    // It is ok if send returns Err, because there might be
                    // no receiver handles in this moment.
                    let _ = self.sender.send(Bytes::copy_from_slice(buffer));
                }
            }
        }
    }
}
