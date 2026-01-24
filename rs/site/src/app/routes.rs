use crate::app::state::AppState;
use askama::Template;
use axum::{
    extract::{Path, State},
    http::StatusCode,
    response::{Html, IntoResponse, Response},
    routing::get,
};
use chrono::{Datelike, NaiveDate};
use markdown::to_html;
use std::{collections::BTreeMap, sync::Arc};

pub fn build_router(state: Arc<AppState>) -> axum::Router {
    axum::Router::new()
        .route("/", get(index_get))
        .route("/blog", get(blog_index_get))
        .route("/{year}/{month}/{day}/{slug}", get(article_get))
        .with_state(state)
}

#[derive(Template)]
#[template(path = "index.html")]
struct IndexTemplate {}

pub async fn index_get() -> Result<Response, StatusCode> {
    IndexTemplate {}.render().map_or_else(
        |_| Err(StatusCode::INTERNAL_SERVER_ERROR),
        |rendered| Ok(Html(rendered).into_response()),
    )
}

struct ArticleLink {
    title: String,
    url: String,
    date: NaiveDate,
}

struct MonthGroup {
    label: String,
    articles: Vec<ArticleLink>,
}

#[derive(Template)]
#[template(path = "blog/index.html")]
struct BlogIndexTemplate {
    months: Vec<MonthGroup>,
}

pub async fn blog_index_get(State(state): State<Arc<AppState>>) -> Result<Response, StatusCode> {
    let mut grouped: BTreeMap<(i32, u32), Vec<&lib::Document>> = BTreeMap::new();

    for document in &state.documents {
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
                .map(|document| ArticleLink {
                    title: document.title.clone(),
                    url: format!(
                        "/{}/{:02}/{:02}/{}",
                        document.date.year(),
                        document.date.month(),
                        document.date.day(),
                        document.slug
                    ),
                    date: document.date,
                })
                .collect();

            articles.sort_by(|left, right| {
                left
                    .date
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

    BlogIndexTemplate { months }.render().map_or_else(
        |_| Err(StatusCode::INTERNAL_SERVER_ERROR),
        |rendered| Ok(Html(rendered).into_response()),
    )
}

#[derive(Template)]
#[template(path = "article.html")]
struct ArticleTemplate {
    title: String,
    date: String,
    content: String,
}

fn format_article_date(date: NaiveDate) -> String {
    let day = date.day();
    let suffix = match day {
        11..=13 => "th",
        _ => match day % 10 {
            1 => "st",
            2 => "nd",
            3 => "rd",
            _ => "th",
        },
    };

    format!(
        "Written on {}, the {day}{suffix} of {} {}",
        date.format("%A"),
        date.format("%B"),
        date.year()
    )
}

pub async fn article_get(
    Path((year, month, day, slug)): Path<(i32, u32, u32, String)>,
    State(state): State<Arc<AppState>>,
) -> Result<Response, StatusCode> {
    let requested_date = NaiveDate::from_ymd_opt(year, month, day).ok_or(StatusCode::NOT_FOUND)?;
    let document = state
        .documents
        .iter()
        .find(|document| document.slug == slug && document.date == requested_date)
        .ok_or(StatusCode::NOT_FOUND)?;
    ArticleTemplate {
        title: document.title.clone(),
        date: format_article_date(document.date),
        content: to_html(&document.content),
    }
    .render()
    .map_or_else(
        |_| Err(StatusCode::INTERNAL_SERVER_ERROR),
        |rendered| Ok(Html(rendered).into_response()),
    )
}
