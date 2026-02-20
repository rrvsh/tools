use std::sync::mpsc::{Receiver, RecvTimeoutError};
use std::time::{Duration, Instant};

/// Runs a debounce loop and invokes `on_apply` once event bursts settle.
///
/// # Errors
/// Returns an error when the callback reports one.
pub fn run_debounced<F>(
    events: &Receiver<String>,
    debounce: Duration,
    mut on_apply: F,
) -> Result<(), String>
where
    F: FnMut() -> Result<(), String>,
{
    let mut pending = false;
    let mut last_signal: Option<Instant> = None;
    let poll_interval = std::cmp::min(Duration::from_millis(25), debounce);

    loop {
        match events.recv_timeout(poll_interval) {
            Ok(event) => {
                if is_relevant_event(&event) {
                    pending = true;
                    last_signal = Some(Instant::now());
                }
            }
            Err(RecvTimeoutError::Timeout) => {
                if pending && last_signal.is_some_and(|point| point.elapsed() >= debounce) {
                    pending = false;
                    on_apply()?;
                }
            }
            Err(RecvTimeoutError::Disconnected) => {
                if pending {
                    on_apply()?;
                }
                return Ok(());
            }
        }
    }
}

#[must_use]
pub fn is_relevant_event(event: &str) -> bool {
    [
        "openwindow>>",
        "closewindow>>",
        "movewindow>>",
        "workspace>>",
        "activewindow>>",
        "changefloatingmode>>",
    ]
    .iter()
    .any(|prefix| event.starts_with(prefix))
}

#[cfg(test)]
mod tests {
    use std::sync::mpsc;
    use std::sync::{Arc, Mutex};
    use std::thread;
    use std::time::Duration;

    use super::*;

    #[test]
    fn debounce_coalesces_bursty_events() {
        let (tx, rx) = mpsc::channel();
        let count = Arc::new(Mutex::new(0_usize));
        let count_clone = Arc::clone(&count);

        let worker = thread::spawn(move || {
            run_debounced(&rx, Duration::from_millis(50), || {
                {
                    let mut lock = count_clone.lock().unwrap();
                    *lock += 1;
                }
                Ok(())
            })
        });

        tx.send("openwindow>>abc".to_string()).unwrap();
        tx.send("movewindow>>abc".to_string()).unwrap();
        thread::sleep(Duration::from_millis(90));
        tx.send("workspace>>1".to_string()).unwrap();
        thread::sleep(Duration::from_millis(90));
        drop(tx);

        worker.join().unwrap().unwrap();
        assert_eq!(*count.lock().unwrap(), 2);
    }

    #[test]
    fn ignores_irrelevant_events() {
        assert!(!is_relevant_event("monitoradded>>DP-1"));
        assert!(is_relevant_event("workspace>>2"));
    }
}
