use chrono::{Datelike, NaiveDate};
use lib::Document;
use std::collections::BTreeMap;

#[derive(Clone)]
pub struct ArticleLink {
    pub title: String,
    pub url: String,
    pub date: NaiveDate,
    pub slug: String,
    pub content: String,
}

#[derive(Clone)]
pub struct MonthGroup {
    pub label: String,
    pub articles: Vec<ArticleLink>,
}

#[derive(Clone)]
pub struct AppState {
    pub months: Vec<MonthGroup>,
}

impl AppState {
    pub fn new(documents: Vec<Document>) -> Self {
        let mut grouped: BTreeMap<(i32, u32), Vec<Document>> = BTreeMap::new();

        for document in documents {
            grouped
                .entry((document.date.year(), document.date.month()))
                .or_default()
                .push(document);
        }

        let months = grouped
            .into_iter()
            .rev()
            .map(|((year, month), documents)| {
                let mut articles: Vec<ArticleLink> = documents
                    .into_iter()
                    .map(|document| {
                        let date = document.date;
                        let slug = document.slug;
                        ArticleLink {
                            title: document.title,
                            url: format!(
                                "/{}/{:02}/{:02}/{}",
                                date.year(),
                                date.month(),
                                date.day(),
                                slug
                            ),
                            date,
                            slug,
                            content: document.content,
                        }
                    })
                    .collect();

                articles.sort_by(|left, right| {
                    left.date
                        .cmp(&right.date)
                        .then_with(|| right.title.cmp(&left.title))
                });

                let label = NaiveDate::from_ymd_opt(year, month, 1).map_or_else(
                    || format!("{month:02} {year}"),
                    |date| date.format("%B %Y").to_string(),
                );

                MonthGroup { label, articles }
            })
            .collect();

        Self { months }
    }
}
