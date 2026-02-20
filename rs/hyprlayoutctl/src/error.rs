use std::path::PathBuf;

#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("failed to read file {path}: {source}")]
    ReadFile {
        path: PathBuf,
        #[source]
        source: std::io::Error,
    },
    #[error("failed to parse TOML {path}: {source}")]
    ParseToml {
        path: PathBuf,
        #[source]
        source: toml::de::Error,
    },
    #[error("invalid layout `{name}`: {reason}")]
    InvalidLayout { name: String, reason: String },
    #[error("layout `{name}` not found")]
    LayoutNotFound { name: String },
    #[error("layout `{name}` is ambiguous: {sources}")]
    AmbiguousLayout { name: String, sources: String },
    #[error("failed to parse shell-expanded path `{path}`")]
    InvalidExpandedPath { path: String },
    #[error("hyprctl command failed: {detail}")]
    Hyprctl { detail: String },
    #[error("hyprland environment is not ready: {detail}")]
    HyprlandEnv { detail: String },
    #[error("internal error: {detail}")]
    Internal { detail: String },
}

pub type Result<T> = std::result::Result<T, Error>;
