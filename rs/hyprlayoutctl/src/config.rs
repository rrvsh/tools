use std::fs;
use std::path::{Path, PathBuf};

use crate::error::{Error, Result};
use crate::model::{ConfigFile, Layout, LayoutFile};

#[derive(Debug, Clone)]
pub enum LayoutSource {
    Inline,
    File(PathBuf),
}

#[derive(Debug, Clone)]
pub struct Discovery {
    pub key: String,
    pub layout: Layout,
    pub source: LayoutSource,
    pub file_stem: Option<String>,
}

#[derive(Debug, Clone)]
pub struct ResolvedConfig {
    pub config_path: PathBuf,
    pub config: ConfigFile,
    pub layout_dirs: Vec<PathBuf>,
    pub discovered: Vec<Discovery>,
}

/// Returns the default config file path.
///
/// # Errors
/// Returns an error when home-path expansion fails.
pub fn default_config_path() -> Result<PathBuf> {
    expand_home("~/.config/hyprlayoutctl/config.toml")
}

/// Loads config/layout directories and discovers all valid layouts.
///
/// # Errors
/// Returns an error when reading/parsing config or discovered layouts fails.
pub fn load_resolved(
    config_path: Option<PathBuf>,
    cli_layout_dirs: &[PathBuf],
) -> Result<ResolvedConfig> {
    let selected_config = if let Some(path) = config_path {
        path
    } else {
        default_config_path()?
    };

    let config = if selected_config.exists() {
        parse_config(&selected_config)?
    } else {
        ConfigFile::default()
    };

    let layout_dirs = if cli_layout_dirs.is_empty() {
        config
            .general
            .layout_dirs
            .iter()
            .map(|item| expand_home(item))
            .collect::<Result<Vec<_>>>()?
    } else {
        cli_layout_dirs.to_vec()
    };

    let discovered = discover_layouts(&config, &layout_dirs)?;

    Ok(ResolvedConfig {
        config_path: selected_config,
        config,
        layout_dirs,
        discovered,
    })
}

/// Resolves a layout query by direct path first, then by discovered names/stems.
///
/// # Errors
/// Returns an error when no layout matches, multiple layouts match, or parsing fails.
pub fn resolve_layout(query: &str, resolved: &ResolvedConfig) -> Result<Discovery> {
    let query_path = PathBuf::from(query);
    if query_path.exists() {
        return load_layout_file(&query_path, query).map(|layout| Discovery {
            key: layout.name.clone(),
            layout,
            source: LayoutSource::File(query_path.clone()),
            file_stem: query_path
                .file_stem()
                .and_then(|stem| stem.to_str())
                .map(ToString::to_string),
        });
    }

    let matches = resolved
        .discovered
        .iter()
        .filter(|entry| {
            entry.key == query
                || entry.layout.name == query
                || entry.file_stem.as_deref().is_some_and(|stem| stem == query)
        })
        .cloned()
        .collect::<Vec<_>>();

    match matches.len() {
        0 => Err(Error::LayoutNotFound {
            name: query.to_string(),
        }),
        1 => Ok(matches[0].clone()),
        _ => {
            let sources = matches
                .iter()
                .map(|entry| match &entry.source {
                    LayoutSource::Inline => format!("inline:{}", entry.key),
                    LayoutSource::File(path) => path.display().to_string(),
                })
                .collect::<Vec<_>>()
                .join(", ");
            Err(Error::AmbiguousLayout {
                name: query.to_string(),
                sources,
            })
        }
    }
}

fn parse_config(path: &Path) -> Result<ConfigFile> {
    let raw = fs::read_to_string(path).map_err(|source| Error::ReadFile {
        path: path.to_path_buf(),
        source,
    })?;
    toml::from_str::<ConfigFile>(&raw).map_err(|source| Error::ParseToml {
        path: path.to_path_buf(),
        source,
    })
}

fn discover_layouts(config: &ConfigFile, layout_dirs: &[PathBuf]) -> Result<Vec<Discovery>> {
    let mut output = Vec::new();

    for layout in config.inline_layouts() {
        layout.validate()?;
        output.push(Discovery {
            key: layout.name.clone(),
            layout,
            source: LayoutSource::Inline,
            file_stem: None,
        });
    }

    for directory in layout_dirs {
        if !directory.exists() {
            continue;
        }
        for entry in fs::read_dir(directory).map_err(|source| Error::ReadFile {
            path: directory.clone(),
            source,
        })? {
            let item = entry.map_err(|source| Error::ReadFile {
                path: directory.clone(),
                source,
            })?;
            let path = item.path();
            if path.extension().and_then(|ext| ext.to_str()) != Some("layout") {
                continue;
            }
            let stem = path
                .file_stem()
                .and_then(|value| value.to_str())
                .ok_or_else(|| Error::InvalidLayout {
                    name: "<file-stem>".to_string(),
                    reason: format!("invalid UTF-8 filename: {}", path.display()),
                })?
                .to_string();
            let layout = load_layout_file(&path, &stem)?;
            output.push(Discovery {
                key: layout.name.clone(),
                layout,
                source: LayoutSource::File(path),
                file_stem: Some(stem),
            });
        }
    }

    Ok(output)
}

fn load_layout_file(path: &Path, fallback_name: &str) -> Result<Layout> {
    let raw = fs::read_to_string(path).map_err(|source| Error::ReadFile {
        path: path.to_path_buf(),
        source,
    })?;
    let parsed = toml::from_str::<LayoutFile>(&raw).map_err(|source| Error::ParseToml {
        path: path.to_path_buf(),
        source,
    })?;
    let layout = parsed.into_layout(fallback_name);
    layout.validate()?;
    Ok(layout)
}

fn expand_home(path: &str) -> Result<PathBuf> {
    let expanded = shellexpand::tilde(path);
    let text = expanded.as_ref();
    if text.is_empty() {
        return Err(Error::InvalidExpandedPath {
            path: path.to_string(),
        });
    }
    Ok(PathBuf::from(text))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;

    fn write_file(path: &Path, content: &str) {
        let mut handle = fs::File::create(path).unwrap();
        handle.write_all(content.as_bytes()).unwrap();
    }

    #[test]
    fn resolves_layout_from_direct_file_path() {
        let temp_dir = tempfile::tempdir().unwrap();
        let layout_path = temp_dir.path().join("dev.layout");
        write_file(
            &layout_path,
            r#"meta.name = "dev"

[[panes]]
name = "all"
rect = { x = "0%", y = "0%", w = "100%", h = "100%" }
content = { kind = "all" }
layout = { kind = "single" }
"#,
        );
        let resolved = load_resolved(None, &[temp_dir.path().to_path_buf()]).unwrap();

        let found = resolve_layout(layout_path.to_string_lossy().as_ref(), &resolved).unwrap();
        assert_eq!(found.layout.name, "dev");
    }

    #[test]
    fn raises_ambiguity_for_duplicate_layout_names() {
        let temp_dir = tempfile::tempdir().unwrap();
        let config_path = temp_dir.path().join("config.toml");
        let layouts_dir = temp_dir.path().join("layouts");
        fs::create_dir_all(&layouts_dir).unwrap();

        write_file(
            &config_path,
            &format!(
                r#"[general]
layout_dirs = ["{}"]

[layouts.dev]
[[layouts.dev.panes]]
name = "all"
rect = {{ x = "0%", y = "0%", w = "100%", h = "100%" }}
content = {{ kind = "all" }}
layout = {{ kind = "single" }}
"#,
                layouts_dir.display()
            ),
        );

        write_file(
            &layouts_dir.join("dev.layout"),
            r#"meta.name = "dev"

[[panes]]
name = "all"
rect = { x = "0%", y = "0%", w = "100%", h = "100%" }
content = { kind = "all" }
layout = { kind = "single" }
"#,
        );

        let resolved = load_resolved(Some(config_path), &[]).unwrap();
        let err = resolve_layout("dev", &resolved).unwrap_err();
        assert!(format!("{err}").contains("ambiguous"));
    }
}
