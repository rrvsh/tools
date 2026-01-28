use crate::app::state::AppState;
use crate::app::views::format_article_date;
use askama::Template;
use axum::{
    extract::{Path, State},
    http::StatusCode,
    response::{Html, IntoResponse, Response},
};
use chrono::NaiveDate;
use markdown::to_html;
use std::sync::Arc;

#[derive(Template)]
#[template(path = "article.html")]
struct ArticleTemplate {
    title: String,
    date: String,
    content: String,
}

pub async fn get(
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
