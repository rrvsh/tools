#![allow(clippy::multiple_crate_versions)]

use std::ffi::OsStr;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Command, ExitStatus};
use std::sync::mpsc;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

use anyhow::{Context, Result, bail};
use notify::{Event, RecursiveMode, Watcher};

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Peer {
    pub name: String,
    pub url: String,
}

#[derive(Clone, Debug)]
pub struct SyncConfig {
    pub repo: PathBuf,
    pub branch: String,
    pub peers: Vec<Peer>,
}

/// Runs one full autosync cycle for a repository.
///
/// # Errors
/// Returns an error if git commands fail, peer sync fails, or conflict handling fails.
pub fn sync_once(config: &SyncConfig) -> Result<()> {
    ensure_repo_exists(&config.repo)?;
    auto_commit_if_needed(config)?;

    for peer in &config.peers {
        sync_peer(config, peer)
            .with_context(|| format!("failed while syncing peer '{}'", peer.name))?;
    }

    Ok(())
}

/// Watches the repository and runs autosync after debounce intervals.
///
/// # Errors
/// Returns an error if watcher setup fails or the watcher channel disconnects.
pub fn watch_and_sync(config: &SyncConfig, debounce: Duration) -> Result<()> {
    ensure_repo_exists(&config.repo)?;

    let (tx, rx) = mpsc::channel();
    let mut watcher = notify::recommended_watcher(move |result: notify::Result<Event>| {
        let _ = tx.send(result);
    })
    .context("failed to create filesystem watcher")?;

    watcher
        .watch(&config.repo, RecursiveMode::Recursive)
        .with_context(|| format!("failed to watch '{}'", config.repo.display()))?;

    let mut pending = false;
    let mut last_event_at = Instant::now();

    loop {
        match rx.recv_timeout(Duration::from_secs(1)) {
            Ok(Ok(event)) => {
                if !event.paths.iter().any(|path| is_git_internal_path(path)) {
                    pending = true;
                    last_event_at = Instant::now();
                }
            }
            Ok(Err(err)) => {
                eprintln!("watcher error: {err}");
            }
            Err(mpsc::RecvTimeoutError::Timeout) => {
                if pending && last_event_at.elapsed() >= debounce {
                    if let Err(err) = sync_once(config) {
                        eprintln!("sync failed: {err:#}");
                    }
                    pending = false;
                }
            }
            Err(mpsc::RecvTimeoutError::Disconnected) => {
                bail!("watcher channel disconnected")
            }
        }
    }
}

#[must_use]
pub fn build_ssh_peers(repo: &Path, hosts: &[String]) -> Vec<Peer> {
    hosts
        .iter()
        .map(|host| Peer {
            name: host.clone(),
            url: format!("ssh://{host}{}", repo.display()),
        })
        .collect()
}

fn sync_peer(config: &SyncConfig, peer: &Peer) -> Result<()> {
    let remote_name = remote_name_for_peer(&peer.name);
    ensure_remote(&config.repo, &remote_name, &peer.url)?;

    let pull = run_git(
        &config.repo,
        [
            "pull",
            "--rebase",
            remote_name.as_str(),
            config.branch.as_str(),
        ],
    )?;
    if !pull.status.success() {
        if is_missing_remote_branch_error(&pull.stderr) {
            // First-time sync to a new peer branch. Continue with push.
        } else if has_unmerged_paths(&config.repo)? {
            write_merge_conflict_file(config, peer, &pull)?;
            let _ = run_git(&config.repo, ["rebase", "--abort"]);
            bail!("rebase conflict with peer '{}'", peer.name);
        } else {
            bail!(
                "git pull --rebase failed for peer '{}': {}",
                peer.name,
                String::from_utf8_lossy(&pull.stderr)
            );
        }
    }

    let push = run_git(
        &config.repo,
        ["push", remote_name.as_str(), config.branch.as_str()],
    )?;
    if !push.status.success() {
        bail!(
            "git push failed for peer '{}': {}",
            peer.name,
            String::from_utf8_lossy(&push.stderr)
        );
    }

    Ok(())
}

fn ensure_repo_exists(repo: &Path) -> Result<()> {
    if !repo.exists() {
        bail!("repo path does not exist: {}", repo.display());
    }

    let output = run_git(repo, ["rev-parse", "--git-dir"])?;
    if !output.status.success() {
        bail!("path is not a git repository: {}", repo.display());
    }
    Ok(())
}

fn auto_commit_if_needed(config: &SyncConfig) -> Result<()> {
    let add = run_git(&config.repo, ["add", "-A"])?;
    if !add.status.success() {
        bail!(
            "git add -A failed: {}",
            String::from_utf8_lossy(&add.stderr)
        );
    }

    let status = run_git(&config.repo, ["status", "--porcelain"])?;
    if !status.status.success() {
        bail!(
            "git status --porcelain failed: {}",
            String::from_utf8_lossy(&status.stderr)
        );
    }

    if status.stdout.is_empty() {
        return Ok(());
    }

    let host = hostname::get()
        .ok()
        .and_then(|h| h.into_string().ok())
        .unwrap_or_else(|| String::from("unknown-host"));
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    let message = format!("autosync: {host} {now}");

    let commit = run_git(&config.repo, ["commit", "-m", message.as_str()])?;
    if !commit.status.success() {
        bail!(
            "git commit failed: {}",
            String::from_utf8_lossy(&commit.stderr)
        );
    }

    Ok(())
}

fn ensure_remote(repo: &Path, remote_name: &str, remote_url: &str) -> Result<()> {
    let get_url = run_git(repo, ["remote", "get-url", remote_name])?;
    if get_url.status.success() {
        let existing = String::from_utf8_lossy(&get_url.stdout).trim().to_string();
        if existing != remote_url {
            let set_url = run_git(repo, ["remote", "set-url", remote_name, remote_url])?;
            if !set_url.status.success() {
                bail!(
                    "failed to update remote '{remote_name}': {}",
                    String::from_utf8_lossy(&set_url.stderr)
                );
            }
        }
        return Ok(());
    }

    let add = run_git(repo, ["remote", "add", remote_name, remote_url])?;
    if !add.status.success() {
        bail!(
            "failed to add remote '{remote_name}': {}",
            String::from_utf8_lossy(&add.stderr)
        );
    }

    Ok(())
}

fn has_unmerged_paths(repo: &Path) -> Result<bool> {
    let output = run_git(repo, ["ls-files", "-u"])?;
    if !output.status.success() {
        bail!(
            "git ls-files -u failed: {}",
            String::from_utf8_lossy(&output.stderr)
        );
    }

    Ok(!output.stdout.is_empty())
}

fn write_merge_conflict_file(config: &SyncConfig, peer: &Peer, pull: &GitOutput) -> Result<()> {
    let conflict_path = config.repo.join("MERGE_CONFLICT");

    let status = run_git(&config.repo, ["status", "--short"])?;
    let unresolved = run_git(&config.repo, ["diff", "--name-only", "--diff-filter=U"])?;
    let conflict_diff = run_git(&config.repo, ["diff", "--merge"])?;

    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);

    let content = format!(
        "conflict_at_unix={now}\npeer={}\nbranch={}\n\n[pull_stderr]\n{}\n\n[status_short]\n{}\n\n[unmerged_files]\n{}\n\n[conflict_diff]\n{}\n",
        peer.name,
        config.branch,
        String::from_utf8_lossy(&pull.stderr),
        String::from_utf8_lossy(&status.stdout),
        String::from_utf8_lossy(&unresolved.stdout),
        String::from_utf8_lossy(&conflict_diff.stdout)
    );

    fs::write(&conflict_path, content)
        .with_context(|| format!("failed to write '{}'", conflict_path.display()))?;

    Ok(())
}

fn is_git_internal_path(path: &Path) -> bool {
    path.components()
        .any(|component| component.as_os_str() == OsStr::new(".git"))
}

fn is_missing_remote_branch_error(stderr: &[u8]) -> bool {
    let text = String::from_utf8_lossy(stderr);
    text.contains("couldn't find remote ref") || text.contains("no such ref was fetched")
}

fn remote_name_for_peer(peer: &str) -> String {
    let mut out = String::from("peer-");
    for ch in peer.chars() {
        if ch.is_ascii_alphanumeric() || ch == '-' {
            out.push(ch);
        } else {
            out.push('-');
        }
    }
    out
}

struct GitOutput {
    status: ExitStatus,
    stdout: Vec<u8>,
    stderr: Vec<u8>,
}

fn run_git<I, S>(repo: &Path, args: I) -> Result<GitOutput>
where
    I: IntoIterator<Item = S>,
    S: AsRef<OsStr>,
{
    let output = Command::new("git")
        .args(args)
        .current_dir(repo)
        .output()
        .with_context(|| format!("failed to execute git in '{}'", repo.display()))?;

    Ok(GitOutput {
        status: output.status,
        stdout: output.stdout,
        stderr: output.stderr,
    })
}

#[must_use]
pub fn parse_hosts_list(input: &str) -> Vec<String> {
    input
        .split(',')
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .map(ToOwned::to_owned)
        .collect()
}

/// Builds a validated [`SyncConfig`] using SSH host peers.
///
/// # Errors
/// Returns an error when no hosts are provided.
pub fn build_config_for_hosts(repo: &Path, branch: &str, hosts: &[String]) -> Result<SyncConfig> {
    if hosts.is_empty() {
        bail!("at least one host is required");
    }

    Ok(SyncConfig {
        repo: repo.to_path_buf(),
        branch: branch.to_string(),
        peers: build_ssh_peers(repo, hosts),
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::process::Command;

    use tempfile::TempDir;

    #[test]
    fn parses_hosts_list() {
        let hosts = parse_hosts_list("alpha, beta ,,gamma");
        assert_eq!(hosts, vec!["alpha", "beta", "gamma"]);
    }

    #[test]
    fn sanitizes_remote_name() {
        let remote = remote_name_for_peer("alpha.local:2222");
        assert_eq!(remote, "peer-alpha-local-2222");
    }

    #[test]
    fn sync_once_pushes_to_peer_non_bare_repo() -> Result<()> {
        let temp = TempDir::new()?;
        let repo_a = temp.path().join("a");
        let repo_b = temp.path().join("b");
        fs::create_dir_all(&repo_a)?;
        fs::create_dir_all(&repo_b)?;

        init_repo(&repo_a)?;
        init_repo(&repo_b)?;
        configure_receive_update_instead(&repo_a)?;
        configure_receive_update_instead(&repo_b)?;

        fs::write(repo_a.join("note.txt"), "v1\n")?;
        git(&repo_a, ["add", "note.txt"])?;
        git(&repo_a, ["commit", "-m", "initial"])?;

        let config = SyncConfig {
            repo: repo_a.clone(),
            branch: String::from("main"),
            peers: vec![Peer {
                name: String::from("b"),
                url: repo_b.display().to_string(),
            }],
        };

        sync_once(&config)?;

        fs::write(repo_a.join("note.txt"), "v2\n")?;
        sync_once(&config)?;

        let content_b = fs::read_to_string(repo_b.join("note.txt"))?;
        assert_eq!(content_b, "v2\n");
        Ok(())
    }

    #[test]
    fn writes_merge_conflict_file_on_rebase_conflict() -> Result<()> {
        let temp = TempDir::new()?;
        let repo_a = temp.path().join("a");
        let repo_b = temp.path().join("b");
        fs::create_dir_all(&repo_a)?;
        fs::create_dir_all(&repo_b)?;

        init_repo(&repo_a)?;
        init_repo(&repo_b)?;
        configure_receive_update_instead(&repo_a)?;
        configure_receive_update_instead(&repo_b)?;

        fs::write(repo_a.join("shared.txt"), "base\n")?;
        git(&repo_a, ["add", "shared.txt"])?;
        git(&repo_a, ["commit", "-m", "base"])?;

        git(
            &repo_a,
            ["remote", "add", "seed", repo_b.to_str().unwrap_or("")],
        )?;
        git(&repo_a, ["push", "seed", "main"])?;

        fs::write(repo_a.join("shared.txt"), "from-a\n")?;
        git(&repo_a, ["add", "shared.txt"])?;
        git(&repo_a, ["commit", "-m", "a-change"])?;

        fs::write(repo_b.join("shared.txt"), "from-b\n")?;
        git(&repo_b, ["add", "shared.txt"])?;
        git(&repo_b, ["commit", "-m", "b-change"])?;

        let config = SyncConfig {
            repo: repo_a.clone(),
            branch: String::from("main"),
            peers: vec![Peer {
                name: String::from("b"),
                url: repo_b.display().to_string(),
            }],
        };

        let result = sync_once(&config);
        assert!(result.is_err());

        let conflict_file = repo_a.join("MERGE_CONFLICT");
        assert!(conflict_file.exists());

        let conflict_content = fs::read_to_string(conflict_file)?;
        assert!(conflict_content.contains("peer=b"));
        assert!(conflict_content.contains("shared.txt"));

        Ok(())
    }

    fn init_repo(repo: &Path) -> Result<()> {
        git(repo, ["init", "-b", "main"])?;
        git(repo, ["config", "user.email", "tests@example.com"])?;
        git(repo, ["config", "user.name", "Test User"])?;
        Ok(())
    }

    fn configure_receive_update_instead(repo: &Path) -> Result<()> {
        git(
            repo,
            ["config", "receive.denyCurrentBranch", "updateInstead"],
        )?;
        git(repo, ["config", "receive.denyNonFastForwards", "true"])?;
        git(repo, ["config", "receive.denyDeletes", "true"])?;
        Ok(())
    }

    fn git<I, S>(repo: &Path, args: I) -> Result<()>
    where
        I: IntoIterator<Item = S>,
        S: AsRef<OsStr>,
    {
        let status = Command::new("git").args(args).current_dir(repo).status()?;
        if !status.success() {
            return Err(anyhow::anyhow!("git command failed in {}", repo.display()));
        }
        Ok(())
    }
}
