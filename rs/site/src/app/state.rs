use crate::app::models::document::Document;
use crate::app::views::{ArticleLink, MonthGroup};
use chrono::Datelike;
use std::collections::{BTreeMap, HashMap};

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
                        let article = ArticleLink::from_document(&document);
                        articles_by_key.insert(
                            (date.year(), date.month(), date.day(), document.slug),
                            article.clone(),
                        );
                        article
                    })
                    .collect::<Vec<ArticleLink>>();

                articles.sort_by(|left, right| {
                    right
                        .date
                        .cmp(&left.date)
                        .then_with(|| left.title.cmp(&right.title))
                });

                MonthGroup::new(year, month, articles)
            })
            .collect();

        Self {
            months,
            articles_by_key,
        }
    }
}
