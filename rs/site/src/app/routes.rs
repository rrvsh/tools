use crate::app::state::{AppState, MonthGroup};
use askama::Template;
use axum::{
    extract::{Path, State},
    http::StatusCode,
    response::{Html, IntoResponse, Response},
    routing::get,
};
use chrono::{Datelike, NaiveDate};
use markdown::to_html;
use std::sync::Arc;

pub fn build_router(state: Arc<AppState>) -> axum::Router {
    axum::Router::new()
        .route("/", get(index_get))
        .route("/{year}/{month}/{day}/{slug}", get(article_get))
        .with_state(state)
}

#[derive(Template)]
#[template(path = "index.html")]
struct IndexTemplate {
    months: Vec<MonthGroup>,
}

pub async fn index_get(State(state): State<Arc<AppState>>) -> Result<Response, StatusCode> {
    IndexTemplate {
        months: state.months.clone(),
    }
    .render()
    .map_or_else(
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
        "written on {}, the {day}{suffix} of {} {}",
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
        .articles_by_key
        .get(&(year, month, day, slug))
        .ok_or(StatusCode::NOT_FOUND)?;
    ArticleTemplate {
        title: document.title.clone(),
        date: format_article_date(requested_date),
        content: to_html(&document.content),
    }
    .render()
    .map_or_else(
        |_| Err(StatusCode::INTERNAL_SERVER_ERROR),
        |rendered| Ok(Html(rendered).into_response()),
    )
}
