use serde::Deserialize;
use std::collections::{BTreeMap, HashSet};

use crate::error::{Error, Result};

#[derive(Debug, Clone, Deserialize, Default)]
pub struct ConfigFile {
    #[serde(default)]
    pub general: GeneralConfig,
    #[serde(default)]
    pub apps: AppsConfig,
    #[serde(default)]
    pub layouts: BTreeMap<String, LayoutBody>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct LayoutFile {
    #[serde(default)]
    pub meta: LayoutMeta,
    #[serde(default)]
    pub defaults: Defaults,
    #[serde(default)]
    pub panes: Vec<PaneDef>,
}

#[derive(Debug, Clone, Deserialize, Default)]
pub struct LayoutMeta {
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub id: String,
}

#[derive(Debug, Clone, Deserialize, Default)]
pub struct GeneralConfig {
    #[serde(default = "default_layout_dirs")]
    pub layout_dirs: Vec<String>,
}

fn default_layout_dirs() -> Vec<String> {
    vec!["~/.config/hyprlayoutctl/layouts".to_string()]
}

#[derive(Debug, Clone, Deserialize, Default)]
pub struct AppsConfig {
    #[serde(default = "default_ghostty")]
    pub ghostty_cmd: String,
    #[serde(default)]
    pub camera_classes: Vec<String>,
}

fn default_ghostty() -> String {
    "ghostty".to_string()
}

#[derive(Debug, Clone, Deserialize, Default)]
pub struct LayoutBody {
    #[serde(default)]
    pub defaults: Defaults,
    #[serde(default)]
    pub panes: Vec<PaneDef>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct PaneDef {
    pub name: String,
    pub rect: RectDef,
    pub content: ContentRule,
    pub layout: PaneLayout,
}

#[derive(Debug, Clone, Deserialize)]
pub struct RectDef {
    pub x: Scalar,
    pub y: Scalar,
    pub w: Scalar,
    pub h: Scalar,
}

#[derive(Debug, Clone, Copy, Deserialize, Default)]
pub struct Defaults {
    #[serde(default)]
    pub gap_px: i32,
    #[serde(default)]
    pub padding_px: i32,
    #[serde(default = "default_tall_bias")]
    pub tall_bias: f64,
}

const fn default_tall_bias() -> f64 {
    1.35
}

#[derive(Debug, Clone, Deserialize)]
pub struct ContentRule {
    pub kind: ContentKind,
    #[serde(default)]
    pub pick: Vec<String>,
    #[serde(default)]
    pub except_panes: Vec<String>,
    #[serde(default)]
    pub ensure: bool,
    #[serde(default)]
    pub ensure_min: Option<usize>,
    #[serde(default)]
    pub fallback: Option<String>,
    #[serde(default, rename = "match")]
    pub match_terms: Vec<String>,
}

#[derive(Debug, Clone, Copy, Deserialize, Eq, PartialEq)]
#[serde(rename_all = "snake_case")]
pub enum ContentKind {
    PickOne,
    All,
    AllExcept,
    Match,
}

#[derive(Debug, Clone, Deserialize)]
pub struct PaneLayout {
    pub kind: PaneLayoutKind,
    #[serde(default)]
    pub preference: Option<GridPreference>,
}

#[derive(Debug, Clone, Copy, Deserialize, Eq, PartialEq)]
#[serde(rename_all = "snake_case")]
pub enum PaneLayoutKind {
    Single,
    Grid,
}

#[derive(Debug, Clone, Copy, Deserialize, Eq, PartialEq)]
#[serde(rename_all = "snake_case")]
pub enum GridPreference {
    Tall,
    Wide,
    Square,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(untagged)]
pub enum Scalar {
    Int(i32),
    Float(f64),
    Text(String),
}

#[derive(Debug, Clone)]
pub struct Layout {
    pub name: String,
    pub id: String,
    pub defaults: Defaults,
    pub panes: Vec<PaneDef>,
}

impl Layout {
    /// Validates layout invariants.
    ///
    /// # Errors
    /// Returns an error when pane names/rectangles/content rules are invalid.
    pub fn validate(&self) -> Result<()> {
        if self.panes.is_empty() {
            return Err(Error::InvalidLayout {
                name: self.name.clone(),
                reason: "layout has no panes".to_string(),
            });
        }

        let mut pane_names = HashSet::new();
        for pane in &self.panes {
            if pane.name.trim().is_empty() {
                return Err(Error::InvalidLayout {
                    name: self.name.clone(),
                    reason: "pane name must not be empty".to_string(),
                });
            }
            if !pane_names.insert(pane.name.clone()) {
                return Err(Error::InvalidLayout {
                    name: self.name.clone(),
                    reason: format!("duplicate pane name `{}`", pane.name),
                });
            }
            if pane.content.kind == ContentKind::PickOne && pane.content.pick.is_empty() {
                return Err(Error::InvalidLayout {
                    name: self.name.clone(),
                    reason: format!("pane `{}` pick_one requires non-empty `pick`", pane.name),
                });
            }
            if pane.content.kind == ContentKind::Match && pane.content.match_terms.is_empty() {
                return Err(Error::InvalidLayout {
                    name: self.name.clone(),
                    reason: format!("pane `{}` match requires non-empty `match`", pane.name),
                });
            }
            pane.rect.validate(&self.name, &pane.name)?;
        }

        let sample = self
            .panes
            .iter()
            .map(|pane| {
                pane.rect
                    .to_px(10_000, 10_000)
                    .map(|r| (pane.name.clone(), r))
            })
            .collect::<Result<Vec<_>>>()?;

        for (idx, (left_name, left)) in sample.iter().enumerate() {
            for (right_name, right) in sample.iter().skip(idx + 1) {
                if left.overlaps(*right) {
                    return Err(Error::InvalidLayout {
                        name: self.name.clone(),
                        reason: format!("panes `{left_name}` and `{right_name}` overlap"),
                    });
                }
            }
        }
        Ok(())
    }
}

impl RectDef {
    /// Validates a rectangle definition in the context of a pane.
    ///
    /// # Errors
    /// Returns an error when resulting rectangle dimensions are invalid.
    pub fn validate(&self, layout_name: &str, pane_name: &str) -> Result<()> {
        let rect = self.to_px(10_000, 10_000)?;
        if rect.w <= 0 || rect.h <= 0 {
            return Err(Error::InvalidLayout {
                name: layout_name.to_string(),
                reason: format!("pane `{pane_name}` has non-positive size"),
            });
        }
        Ok(())
    }

    /// Resolves a rectangle from relative/pixel units to absolute pixels.
    ///
    /// # Errors
    /// Returns an error when any scalar is invalid.
    pub fn to_px(&self, width: i32, height: i32) -> Result<PxRect> {
        Ok(PxRect {
            x: self.x.resolve(width)?,
            y: self.y.resolve(height)?,
            w: self.w.resolve(width)?,
            h: self.h.resolve(height)?,
        })
    }
}

#[derive(Debug, Clone, Copy)]
pub struct PxRect {
    pub x: i32,
    pub y: i32,
    pub w: i32,
    pub h: i32,
}

impl PxRect {
    #[must_use]
    pub const fn overlaps(self, other: Self) -> bool {
        let self_right = self.x + self.w;
        let self_bottom = self.y + self.h;
        let other_right = other.x + other.w;
        let other_bottom = other.y + other.h;

        self.x < other_right
            && self_right > other.x
            && self.y < other_bottom
            && self_bottom > other.y
    }
}

impl Scalar {
    /// Resolves scalar value against a total pixel size.
    ///
    /// # Errors
    /// Returns an error when text scalar parsing fails.
    #[allow(clippy::cast_possible_truncation)]
    pub fn resolve(&self, total: i32) -> Result<i32> {
        match self {
            Self::Int(value) => Ok(*value),
            Self::Float(value) => Ok(*value as i32),
            Self::Text(text) => parse_scalar_text(text, total),
        }
    }
}

#[allow(clippy::cast_possible_truncation)]
fn parse_scalar_text(text: &str, total: i32) -> Result<i32> {
    let trimmed = text.trim();
    if let Some(raw_percent) = trimmed.strip_suffix('%') {
        let percent = raw_percent
            .trim()
            .parse::<f64>()
            .map_err(|_| Error::InvalidLayout {
                name: "<unknown>".to_string(),
                reason: format!("invalid percentage value `{trimmed}`"),
            })?;
        Ok(((f64::from(total) * percent) / 100.0).round() as i32)
    } else {
        trimmed.parse::<i32>().map_err(|_| Error::InvalidLayout {
            name: "<unknown>".to_string(),
            reason: format!("invalid numeric value `{trimmed}`"),
        })
    }
}

impl ConfigFile {
    #[must_use]
    pub fn inline_layouts(&self) -> Vec<Layout> {
        self.layouts
            .iter()
            .map(|(name, body)| Layout {
                name: name.clone(),
                id: name.clone(),
                defaults: body.defaults,
                panes: body.panes.clone(),
            })
            .collect()
    }
}

impl LayoutFile {
    #[must_use]
    pub fn into_layout(self, fallback_name: &str) -> Layout {
        let name = if self.meta.name.trim().is_empty() {
            fallback_name.to_string()
        } else {
            self.meta.name
        };
        let id = if self.meta.id.trim().is_empty() {
            name.clone()
        } else {
            self.meta.id
        };

        Layout {
            name,
            id,
            defaults: self.defaults,
            panes: self.panes,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_percent_scalar() {
        let value = Scalar::Text("25%".to_string()).resolve(800).unwrap();
        assert_eq!(value, 200);
    }

    #[test]
    fn rejects_overlapping_panes() {
        let layout = Layout {
            name: "test".to_string(),
            id: "test".to_string(),
            defaults: Defaults::default(),
            panes: vec![
                PaneDef {
                    name: "a".to_string(),
                    rect: RectDef {
                        x: Scalar::Text("0%".to_string()),
                        y: Scalar::Text("0%".to_string()),
                        w: Scalar::Text("60%".to_string()),
                        h: Scalar::Text("100%".to_string()),
                    },
                    content: ContentRule {
                        kind: ContentKind::All,
                        pick: vec![],
                        except_panes: vec![],
                        ensure: false,
                        ensure_min: None,
                        fallback: None,
                        match_terms: vec![],
                    },
                    layout: PaneLayout {
                        kind: PaneLayoutKind::Single,
                        preference: None,
                    },
                },
                PaneDef {
                    name: "b".to_string(),
                    rect: RectDef {
                        x: Scalar::Text("50%".to_string()),
                        y: Scalar::Text("0%".to_string()),
                        w: Scalar::Text("50%".to_string()),
                        h: Scalar::Text("100%".to_string()),
                    },
                    content: ContentRule {
                        kind: ContentKind::All,
                        pick: vec![],
                        except_panes: vec![],
                        ensure: false,
                        ensure_min: None,
                        fallback: None,
                        match_terms: vec![],
                    },
                    layout: PaneLayout {
                        kind: PaneLayoutKind::Single,
                        preference: None,
                    },
                },
            ],
        };

        let error = layout.validate().unwrap_err();
        assert!(format!("{error}").contains("overlap"));
    }
}
