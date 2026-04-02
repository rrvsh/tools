use crate::app::models::document::Document;
use chrono::{Datelike, NaiveDate};
use std::process::Command;

const BASE_TEMPLATE_PATH: &str = "rs/site/templates/base.html";
const GITHUB_BLOB_PREFIX: &str = "https://github.com/rrvsh/tools/blob/prime";
const UNKNOWN_COMMIT_HASH: &str = "unknown";

#[derive(Clone)]
pub struct ArticleLink {
    pub title: String,
    pub url: String,
    pub date: NaiveDate,
    pub content: String,
}

impl ArticleLink {
    pub fn from_document(document: &Document) -> Self {
        Self {
            title: document.title.clone(),
            url: format!(
                "/{}/{:02}/{:02}/{}",
                document.date.year(),
                document.date.month(),
                document.date.day(),
                document.slug
            ),
            date: document.date,
            content: document.content.clone(),
        }
    }
}

#[derive(Clone)]
pub struct MonthGroup {
    pub label: String,
    pub articles: Vec<ArticleLink>,
}

impl MonthGroup {
    pub fn new(year: i32, month: u32, articles: Vec<ArticleLink>) -> Self {
        Self {
            label: NaiveDate::from_ymd_opt(year, month, 1).map_or_else(
                || format!("{month:02} {year}"),
                |date| date.format("%B %Y").to_string(),
            ),
            articles,
        }
    }
}

pub fn format_article_date(date: NaiveDate) -> String {
    let day = date.day();
    let suffix = match day % 100 {
        11..=13 => "th",
        _ => match day % 10 {
            1 => "st",
            2 => "nd",
            3 => "rd",
            _ => "th",
        },
    };

    format!(
        "{}, the {day}{suffix} of {} {}",
        date.format("%A"),
        date.format("%B"),
        date.year()
    )
}

pub fn base_template_github_url() -> String {
    format!("{GITHUB_BLOB_PREFIX}/{BASE_TEMPLATE_PATH}")
}

pub fn shorten_commit_hash(raw_hash: &str) -> String {
    raw_hash.trim().chars().take(7).collect()
}

pub fn current_commit_hash() -> String {
    std::env::var("GIT_COMMIT_HASH")
        .or_else(|_| std::env::var("GITHUB_SHA"))
        .ok()
        .map(|sha| shorten_commit_hash(&sha))
        .filter(|sha| !sha.is_empty())
        .or_else(read_git_short_commit_hash)
        .unwrap_or_else(|| UNKNOWN_COMMIT_HASH.to_string())
}

fn read_git_short_commit_hash() -> Option<String> {
    Command::new("git")
        .args(["rev-parse", "--short", "HEAD"])
        .output()
        .ok()
        .filter(|output| output.status.success())
        .map(|output| String::from_utf8_lossy(&output.stdout).to_string())
        .map(|hash| shorten_commit_hash(&hash))
        .filter(|hash| !hash.is_empty())
}

#[cfg(test)]
mod tests {
    use super::{base_template_github_url, shorten_commit_hash};

    #[test]
    fn base_template_github_url_uses_prime_branch_prefix() {
        let url = base_template_github_url();
        assert_eq!(
            url,
            "https://github.com/rrvsh/tools/blob/prime/rs/site/templates/base.html"
        );
    }

    #[test]
    fn shorten_commit_hash_trims_and_limits_to_seven_characters() {
        assert_eq!(shorten_commit_hash("  abcdef123456\n"), "abcdef1");
    }
}
