use crate::app::models::document::Document;
use chrono::{Datelike, NaiveDate};

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
