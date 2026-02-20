use std::io::{BufRead, BufReader};
use std::os::unix::net::UnixStream;
use std::path::PathBuf;
use std::process::Command;
use std::sync::mpsc::{self, Receiver};
use std::thread;

use serde::Deserialize;

use crate::engine::{Client, HyprCommand, Scope};
use crate::error::{Error, Result};
use crate::model::PxRect;

pub trait Runtime {
    /// Returns the currently focused monitor + active workspace scope.
    ///
    /// # Errors
    /// Returns an error when Hyprland cannot provide monitor/workspace information.
    fn scope(&self) -> Result<Scope>;
    /// Returns all known clients from Hyprland.
    ///
    /// # Errors
    /// Returns an error when querying or parsing client data fails.
    fn clients(&self) -> Result<Vec<Client>>;
    /// Dispatches Hyprland commands.
    ///
    /// # Errors
    /// Returns an error when command execution fails.
    fn dispatch(&self, commands: &[HyprCommand], dry_run: bool, verbose: bool) -> Result<()>;
    /// Spawns an application command.
    ///
    /// # Errors
    /// Returns an error when process launch fails.
    fn spawn(&self, command: &str, dry_run: bool, verbose: bool) -> Result<()>;
    /// Subscribes to Hyprland event stream.
    ///
    /// # Errors
    /// Returns an error when event socket connection fails.
    fn subscribe_events(&self) -> Result<Receiver<String>>;
}

#[derive(Debug, Default)]
pub struct HyprRuntime;

impl Runtime for HyprRuntime {
    fn scope(&self) -> Result<Scope> {
        let monitors = hyprctl_json::<Vec<MonitorRaw>>(&["-j", "monitors"])?;
        let focused = monitors
            .into_iter()
            .find(|item| item.focused)
            .ok_or_else(|| Error::Hyprctl {
                detail: "no focused monitor found".to_string(),
            })?;

        Ok(Scope {
            monitor_id: focused.id,
            workspace_id: focused.active_workspace.id,
            monitor_rect: PxRect {
                x: focused.x,
                y: focused.y,
                w: focused.width,
                h: focused.height,
            },
        })
    }

    fn clients(&self) -> Result<Vec<Client>> {
        let raw = hyprctl_json::<Vec<ClientRaw>>(&["-j", "clients"])?;
        Ok(raw
            .into_iter()
            .map(|item| Client {
                address: item.address,
                class: item.class,
                title: item.title,
                monitor_id: item.monitor,
                workspace_id: item.workspace.id,
                floating: item.floating,
                x: item.at.first().copied().unwrap_or_default(),
                y: item.at.get(1).copied().unwrap_or_default(),
                w: item.size.first().copied().unwrap_or(1),
                h: item.size.get(1).copied().unwrap_or(1),
            })
            .collect())
    }

    fn dispatch(&self, commands: &[HyprCommand], dry_run: bool, verbose: bool) -> Result<()> {
        for command in commands {
            let args = hypr_dispatch_args(command);
            if verbose || dry_run {
                println!("hyprctl {}", args.join(" "));
            }
            if dry_run {
                continue;
            }
            let status = Command::new("hyprctl")
                .args(&args)
                .status()
                .map_err(|error| Error::Hyprctl {
                    detail: format!("failed to execute `hyprctl {}`: {error}", args.join(" ")),
                })?;
            if !status.success() {
                return Err(Error::Hyprctl {
                    detail: format!("`hyprctl {}` failed with status {status}", args.join(" ")),
                });
            }
        }
        Ok(())
    }

    fn spawn(&self, command: &str, dry_run: bool, verbose: bool) -> Result<()> {
        if verbose || dry_run {
            println!("spawn: {command}");
        }
        if dry_run {
            return Ok(());
        }

        let status = Command::new("sh")
            .arg("-lc")
            .arg(command)
            .status()
            .map_err(|error| Error::Hyprctl {
                detail: format!("failed to spawn `{command}`: {error}"),
            })?;

        if !status.success() {
            return Err(Error::Hyprctl {
                detail: format!("spawn command `{command}` failed with status {status}"),
            });
        }
        Ok(())
    }

    fn subscribe_events(&self) -> Result<Receiver<String>> {
        let socket_path = hypr_event_socket_path()?;
        let stream = UnixStream::connect(&socket_path).map_err(|error| Error::HyprlandEnv {
            detail: format!(
                "failed to connect to event socket {}: {error}",
                socket_path.display()
            ),
        })?;

        let (tx, rx) = mpsc::channel();
        thread::spawn(move || {
            let reader = BufReader::new(stream);
            for line in reader.lines() {
                let Ok(line_text) = line else {
                    break;
                };
                if tx.send(line_text).is_err() {
                    break;
                }
            }
        });

        Ok(rx)
    }
}

#[derive(Debug, Deserialize)]
struct MonitorRaw {
    id: i32,
    focused: bool,
    x: i32,
    y: i32,
    width: i32,
    height: i32,
    #[serde(rename = "activeWorkspace")]
    active_workspace: WorkspaceRaw,
}

#[derive(Debug, Deserialize)]
struct WorkspaceRaw {
    id: i32,
}

#[derive(Debug, Deserialize)]
struct ClientRaw {
    address: String,
    class: String,
    title: String,
    monitor: i32,
    workspace: WorkspaceRaw,
    floating: bool,
    at: Vec<i32>,
    size: Vec<i32>,
}

fn hyprctl_json<T: for<'de> Deserialize<'de>>(args: &[&str]) -> Result<T> {
    let output = Command::new("hyprctl")
        .args(args)
        .output()
        .map_err(|error| Error::Hyprctl {
            detail: format!("failed to execute hyprctl {}: {error}", args.join(" ")),
        })?;

    if !output.status.success() {
        return Err(Error::Hyprctl {
            detail: format!(
                "hyprctl {} failed: {}",
                args.join(" "),
                String::from_utf8_lossy(&output.stderr)
            ),
        });
    }

    serde_json::from_slice::<T>(&output.stdout).map_err(|error| Error::Hyprctl {
        detail: format!("failed to parse hyprctl json output: {error}"),
    })
}

fn hypr_dispatch_args(command: &HyprCommand) -> Vec<String> {
    match command {
        HyprCommand::SetFloating { address } => {
            vec![
                "dispatch".to_string(),
                "setfloating".to_string(),
                format!("address:{address}"),
            ]
        }
        HyprCommand::Move { address, x, y } => vec![
            "dispatch".to_string(),
            "movewindowpixel".to_string(),
            "exact".to_string(),
            x.to_string(),
            y.to_string(),
            format!("address:{address}"),
        ],
        HyprCommand::Resize { address, w, h } => vec![
            "dispatch".to_string(),
            "resizewindowpixel".to_string(),
            "exact".to_string(),
            w.to_string(),
            h.to_string(),
            format!("address:{address}"),
        ],
    }
}

fn hypr_event_socket_path() -> Result<PathBuf> {
    let runtime_dir = std::env::var("XDG_RUNTIME_DIR").map_err(|_| Error::HyprlandEnv {
        detail: "XDG_RUNTIME_DIR is not set".to_string(),
    })?;
    let signature =
        std::env::var("HYPRLAND_INSTANCE_SIGNATURE").map_err(|_| Error::HyprlandEnv {
            detail: "HYPRLAND_INSTANCE_SIGNATURE is not set".to_string(),
        })?;
    Ok(PathBuf::from(runtime_dir)
        .join("hypr")
        .join(signature)
        .join(".socket2.sock"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn dispatch_serialization_is_correct() {
        let move_cmd = HyprCommand::Move {
            address: "0xabc".to_string(),
            x: 100,
            y: 200,
        };
        assert_eq!(
            hypr_dispatch_args(&move_cmd),
            vec![
                "dispatch",
                "movewindowpixel",
                "exact",
                "100",
                "200",
                "address:0xabc"
            ]
        );
    }
}
