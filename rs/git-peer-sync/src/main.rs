#![allow(clippy::multiple_crate_versions)]

use std::path::{Path, PathBuf};
use std::time::Duration;

use anyhow::{bail, Context, Result};
use clap::{Parser, Subcommand};
use git_peer_sync::{
    build_config_for_hosts, parse_hosts_list, sync_once, watch_and_sync, Peer, SyncConfig,
};

#[derive(Debug, Parser)]
#[command(name = "git-peer-sync")]
#[command(about = "Auto-commit and sync a git repository across peer devices")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Debug, Subcommand)]
enum Commands {
    Watch {
        #[arg(long)]
        repo: PathBuf,
        #[arg(long, default_value = "main")]
        branch: String,
        #[arg(long, value_name = "HOSTS_CSV")]
        hosts: Option<String>,
        #[arg(long = "peer-url", value_name = "NAME=URL")]
        peer_urls: Vec<String>,
        #[arg(long, default_value_t = 10)]
        debounce_seconds: u64,
    },
    SyncOnce {
        #[arg(long)]
        repo: PathBuf,
        #[arg(long, default_value = "main")]
        branch: String,
        #[arg(long, value_name = "HOSTS_CSV")]
        hosts: Option<String>,
        #[arg(long = "peer-url", value_name = "NAME=URL")]
        peer_urls: Vec<String>,
    },
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Watch {
            repo,
            branch,
            hosts,
            peer_urls,
            debounce_seconds,
        } => {
            let config = config_from_args(&repo, &branch, hosts.as_deref(), &peer_urls)?;
            watch_and_sync(&config, Duration::from_secs(debounce_seconds))
        }
        Commands::SyncOnce {
            repo,
            branch,
            hosts,
            peer_urls,
        } => {
            let config = config_from_args(&repo, &branch, hosts.as_deref(), &peer_urls)?;
            sync_once(&config)
        }
    }
}

fn config_from_args(
    repo: &Path,
    branch: &str,
    hosts_csv: Option<&str>,
    peer_urls: &[String],
) -> Result<SyncConfig> {
    if !peer_urls.is_empty() {
        let peers = parse_named_peer_urls(peer_urls)?;
        return Ok(SyncConfig {
            repo: repo.to_path_buf(),
            branch: branch.to_string(),
            peers,
        });
    }

    let Some(hosts_csv) = hosts_csv else {
        bail!("either --hosts or one or more --peer-url entries are required")
    };

    let hosts = parse_hosts_list(hosts_csv);
    build_config_for_hosts(repo, branch, &hosts)
        .with_context(|| format!("invalid host configuration for repo '{}'", repo.display()))
}

fn parse_named_peer_urls(entries: &[String]) -> Result<Vec<Peer>> {
    let mut peers = Vec::with_capacity(entries.len());

    for entry in entries {
        let Some((name, url)) = entry.split_once('=') else {
            bail!("invalid --peer-url '{entry}'; expected NAME=URL")
        };

        let name = name.trim();
        let url = url.trim();
        if name.is_empty() || url.is_empty() {
            bail!("invalid --peer-url '{entry}'; NAME and URL are required");
        }

        peers.push(Peer {
            name: name.to_string(),
            url: url.to_string(),
        });
    }

    Ok(peers)
}
