//! Raw complex FFT capture.
//!
//! This is a single-shot, fixed-size burst of I/Q samples tapped before the
//! spectrometer's integrator discards phase (see maia-hdl's
//! `Spectrometer.raw_capture`), as opposed to the continuous, integrated
//! magnitude waterfall. Modeled on `recording.rs`'s `Recorder*` types, but
//! substantially simpler: no SigMF/tar wrapping, no mode choice (the FPGA
//! side always runs this in 16-bit I/Q), no maximum-duration timer (it's a
//! fixed-size buffer, not something you can let run indefinitely), and no
//! ADC sample-rate metadata (the data is FFT bins, not ADC samples).

use super::json_error::JsonError;
use crate::app::AppState;
use crate::fpga::InterruptWaiter;
use anyhow::Result;
use axum::{Json, body::Body, extract::State};
use bytes::Bytes;
use std::os::unix::io::AsRawFd;
use tokio::fs;
use tokio::sync::{OwnedRwLockWriteGuard, RwLock};

/// Raw capture state.
///
/// This struct contains the state of the raw capture. It is used by the REST
/// API.
#[derive(Debug)]
pub struct RawCaptureState {
    state: tokio::sync::Mutex<maia_json::RawCaptureState>,
    buffer: std::sync::Arc<RwLock<RawCaptureBuffer>>,
    capture_in_progress: tokio::sync::Mutex<Option<OwnedRwLockWriteGuard<RawCaptureBuffer>>>,
}

/// Raw capture finish waiter.
///
/// Mirrors `recording::RecorderFinishWaiter`: waits for the raw_capture
/// interrupt and updates the capture state accordingly. Must be run
/// concurrently with the rest of the application.
#[derive(Debug)]
pub struct RawCaptureFinishWaiter {
    state: AppState,
    waiter: InterruptWaiter,
}

impl RawCaptureState {
    /// Creates a new raw capture state.
    pub async fn new() -> Result<RawCaptureState> {
        Ok(RawCaptureState {
            state: tokio::sync::Mutex::new(maia_json::RawCaptureState::Stopped),
            buffer: std::sync::Arc::new(RwLock::new(RawCaptureBuffer::new().await?)),
            capture_in_progress: tokio::sync::Mutex::new(None),
        })
    }
}

impl RawCaptureFinishWaiter {
    /// Creates a new raw capture finish waiter.
    pub fn new(state: AppState, waiter: InterruptWaiter) -> RawCaptureFinishWaiter {
        RawCaptureFinishWaiter { state, waiter }
    }

    /// Runs the raw capture finish waiter.
    ///
    /// This function loops forever, waiting for interrupts and updating the
    /// state of the raw capture. The function only returns if there is an
    /// error.
    pub async fn run(self) -> Result<()> {
        loop {
            self.waiter.wait().await;
            tracing::info!("raw capture finished");
            {
                let mut in_progress = self.state.raw_capture().capture_in_progress.lock().await;
                if let Some(buffer) = in_progress.as_mut() {
                    // mmap() the buffer again to invalidate the cache
                    **buffer = RawCaptureBuffer::new().await?;
                }
                *in_progress = None;
            }
            *self.state.raw_capture().state.lock().await = maia_json::RawCaptureState::Stopped;
        }
    }
}

async fn raw_capture_json(state: &AppState) -> maia_json::RawCapture {
    maia_json::RawCapture {
        state: *state.raw_capture().state.lock().await,
        dropped_samples: state.ip_core().lock().unwrap().raw_capture_dropped_samples(),
    }
}

pub async fn get_raw_capture(State(state): State<AppState>) -> Json<maia_json::RawCapture> {
    Json(raw_capture_json(&state).await)
}

pub async fn patch_raw_capture(
    State(state): State<AppState>,
    Json(patch): Json<maia_json::PatchRawCapture>,
) -> Result<Json<maia_json::RawCapture>, JsonError> {
    let mut rc_state = state.raw_capture().state.lock().await;
    match (patch.state_change, *rc_state) {
        (
            Some(maia_json::RawCaptureStateChange::Start),
            maia_json::RawCaptureState::Stopped,
        ) => {
            let lock = state
                .raw_capture()
                .buffer
                .clone()
                .try_write_owned()
                .map_err(|_| {
                    JsonError::client_error_alert(anyhow::anyhow!(
                        "cannot start new raw capture: current capture is being accessed"
                    ))
                })?;
            state
                .raw_capture()
                .capture_in_progress
                .lock()
                .await
                .replace(lock);
            *rc_state = maia_json::RawCaptureState::Running;
            state.ip_core().lock().unwrap().raw_capture_start();
        }
        (Some(maia_json::RawCaptureStateChange::Stop), maia_json::RawCaptureState::Running) => {
            // Stays Running until RawCaptureFinishWaiter sees the finish
            // interrupt and flips it to Stopped -- same reasoning as
            // Recorder's Stopping state, just without a separate
            // user-visible transitional state for this simpler v1.
            state.ip_core().lock().unwrap().raw_capture_stop();
        }
        (_, _) => (),
    }
    Ok(Json(maia_json::RawCapture {
        state: *rc_state,
        dropped_samples: state.ip_core().lock().unwrap().raw_capture_dropped_samples(),
    }))
}

/// Returns the raw captured I/Q samples as a flat binary body (16-bit I,
/// 16-bit Q, interleaved little-endian -- see Pack16IQto32's docstring in
/// maia-hdl). No SigMF/tar wrapping for this v1, unlike `/recording`.
pub async fn get_raw_capture_data(State(state): State<AppState>) -> Result<Body, JsonError> {
    let buffer = state
        .raw_capture()
        .buffer
        .clone()
        .try_read_owned()
        .map_err(|_| JsonError::client_error_alert(anyhow::anyhow!("capture in progress")))?;
    let next_address = state.ip_core().lock().unwrap().raw_capture_next_address();
    let size = next_address
        .saturating_sub(buffer.base_address)
        .min(buffer.size);
    let data = unsafe { std::slice::from_raw_parts(buffer.base, size) };
    Ok(Body::from(Bytes::copy_from_slice(data)))
}

#[derive(Debug)]
struct RawCaptureBuffer {
    base: *const u8,
    base_address: usize,
    size: usize,
}

unsafe impl Send for RawCaptureBuffer {}
unsafe impl Sync for RawCaptureBuffer {}

impl RawCaptureBuffer {
    async fn new() -> Result<RawCaptureBuffer> {
        // Attribute names are fixed by the "maia-sdr,recording"-compatible
        // kernel driver (same driver the existing IQ recorder uses), only
        // the /dev and /sys/class/maia-sdr directory names are specific to
        // this device (set by the devicetree node's own name).
        let base_address = usize::from_str_radix(
            fs::read_to_string("/sys/class/maia-sdr/maia-sdr-raw-capture/device/recording_base_address")
                .await?
                .trim_end()
                .trim_start_matches("0x"),
            16,
        )?;
        let size = usize::from_str_radix(
            fs::read_to_string("/sys/class/maia-sdr/maia-sdr-raw-capture/device/recording_size")
                .await?
                .trim_end()
                .trim_start_matches("0x"),
            16,
        )?;
        let mem = fs::OpenOptions::new()
            .read(true)
            .open("/dev/maia-sdr-raw-capture")
            .await?;
        // mmap()'ing the buffer can be quite expensive, because the cache is
        // invalidated. We run it with spawn_blocking (same as
        // RecordingBuffer::new).
        tokio::task::spawn_blocking(move || unsafe {
            match libc::mmap(
                std::ptr::null_mut::<libc::c_void>(),
                size,
                libc::PROT_READ,
                libc::MAP_SHARED,
                mem.as_raw_fd(),
                0,
            ) {
                libc::MAP_FAILED => Err(anyhow::anyhow!("mmap /dev/maia-sdr-raw-capture failed")),
                x => Ok(RawCaptureBuffer {
                    base: x as *const u8,
                    base_address,
                    size,
                }),
            }
        })
        .await?
    }
}

impl Drop for RawCaptureBuffer {
    fn drop(&mut self) {
        unsafe {
            libc::munmap(self.base as *mut libc::c_void, self.size);
        }
    }
}
