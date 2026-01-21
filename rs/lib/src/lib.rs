use serde::Deserialize;
use std::ffi::OsStr;
use std::path::Path;

#[derive(PartialEq, Debug)]
pub struct Document {
    title: String,
    slug: String,
    date: String,
    content: String,
}

#[derive(Deserialize)]
struct ArticleFrontmatter {
    title: Option<String>,
    slug: Option<String>,
    date: Option<String>,
}

impl Document {
    pub fn from_path<P: AsRef<Path>>(path: P) -> Option<Self> {
        let path = path.as_ref();
        let is_markdown = path.extension() == Some(OsStr::new("md"));
        if !path.is_file() && !is_markdown {
            return None;
        }
        let file_content = std::fs::read_to_string(path).ok()?;
        let (frontmatter, content) =
            markdown_frontmatter::parse::<ArticleFrontmatter>(&file_content).ok()?;
        let date = frontmatter.date?;
        let slug = frontmatter.slug?;
        let title = frontmatter.title?;
        Some(Self {
            title,
            slug,
            date,
            content: content.trim().to_string(),
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs::File;
    use std::io::Write;
    use tempfile::tempdir;

    #[test]
    fn document_success() {
        let dir = tempdir().unwrap();
        let file_path = dir.path().join("my-temporary-note.md");
        let mut file = File::create(&file_path).unwrap();
        let doc = r#"---
title: Test
slug: test
date: 2026-01-21
---
Testing..."#;
        writeln!(file, "{}", doc).unwrap();
        let actual = Document::from_path(&file_path);
        let expected = Some(Document {
            title: "Test".to_string(),
            slug: "test".to_string(),
            date: "2026-01-21".to_string(),
            content: "Testing...".to_string(),
        });
        assert!(actual == expected);
    }

    #[test]
    fn document_failure_not_markdown() {
        let dir = tempdir().unwrap();
        let file_path = dir.path().join("my-temporary-note.txt");
        let _ = File::create(&file_path).unwrap();
        let actual = Document::from_path(&file_path);
        let expected = None;
        assert!(actual == expected);
    }

    #[test]
    fn document_failure_not_file() {
        let dir = tempdir().unwrap();
        let file_path = dir.path();
        let actual = Document::from_path(file_path);
        let expected = None;
        assert!(actual == expected);
    }
}
