use chrono::{Datelike, NaiveDate};
use lib::Document;
use std::collections::{BTreeMap, HashMap};

#[derive(Clone)]
pub struct ArticleLink {
    pub title: String,
    pub url: String,
    pub date: NaiveDate,
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
    pub articles_by_key: HashMap<(i32, u32, u32, String), ArticleLink>,
}

impl AppState {
    pub fn new(documents: Vec<Document>) -> Self {
        let mut grouped: BTreeMap<(i32, u32), Vec<Document>> = BTreeMap::new();
        let mut articles_by_key = HashMap::new();

        for document in documents {
            grouped
                .entry((document.date.year(), document.date.month()))
                .or_default()
                .push(document);
        }

        let months = grouped
            .into_iter()
            .rev() // btreemap sorts ascending
            .map(|((year, month), documents)| {
                let mut articles = documents
                    .into_iter()
                    .map(|document| {
                        let date = document.date;
                        let slug = document.slug;
                        let article = ArticleLink {
                            title: document.title,
                            url: format!(
                                "/{}/{:02}/{:02}/{}",
                                date.year(),
                                date.month(),
                                date.day(),
                                slug
                            ),
                            date,
                            content: document.content,
                        };
                        articles_by_key.insert(
                            (date.year(), date.month(), date.day(), slug),
                            article.clone(),
                        );
                        article
                    })
                    .collect::<Vec<ArticleLink>>();

                articles.sort_by(|left, right| {
                    left.date
                        .cmp(&right.date)
                        .then_with(|| right.title.cmp(&left.title))
                });

                MonthGroup {
                    label: NaiveDate::from_ymd_opt(year, month, 1).map_or_else(
                        || format!("{month:02} {year}"),
                        |date| date.format("%B %Y").to_string(),
                    ),
                    articles,
                }
            })
            .collect();

        Self {
            months,
            articles_by_key,
        }
    }
}
