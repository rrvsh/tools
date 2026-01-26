use chrono::NaiveDate;
use ignore::Walk;
use serde::Deserialize;
use std::ffi::OsStr;
use std::path::Path;

#[derive(Clone, PartialEq, Eq, Debug)]
pub struct Document {
    pub title: String,
    pub slug: String,
    pub date: NaiveDate,
    pub content: String,
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
        let date = NaiveDate::parse_from_str(&date, "%Y-%m-%d").ok()?;
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

pub fn load_documents_from_dir<P: AsRef<Path>>(path: P) -> Vec<Document> {
    let mut documents = Walk::new(path)
        .filter_map(std::result::Result::ok)
        .filter_map(|entry| Document::from_path(entry.path()))
        .collect::<Vec<Document>>();
    documents.sort_by(|left, right| right.date.cmp(&left.date));
    documents
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
            date: NaiveDate::from_ymd_opt(2026, 1, 21).unwrap(),
            content: "Testing...".to_string(),
        });
        dbg!(&actual, &expected);
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

    #[test]
    fn document_failure_invalid_date() {
        let dir = tempdir().unwrap();
        let file_path = dir.path().join("my-temporary-note.md");
        let mut file = File::create(&file_path).unwrap();
        let doc = r#"---
 title: Test
 slug: test
 date: not-a-date
 ---
 Testing..."#;
        writeln!(file, "{}", doc).unwrap();
        let actual = Document::from_path(&file_path);
        let expected = None;
        assert!(actual == expected);
    }
}
