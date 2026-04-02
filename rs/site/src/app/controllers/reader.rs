use crate::app::views::{base_template_github_url, current_commit_hash};
use askama::Template;
use axum::{
    http::StatusCode,
    response::{Html, IntoResponse, Response},
};

#[derive(Template)]
#[template(path = "reader.html")]
struct ReaderTemplate {
    base_template_url: String,
    commit_hash: String,
}

pub async fn get() -> Result<Response, StatusCode> {
    ReaderTemplate {
        base_template_url: base_template_github_url(),
        commit_hash: current_commit_hash(),
    }
    .render()
    .map_or_else(
        |_| Err(StatusCode::INTERNAL_SERVER_ERROR),
        |rendered| Ok(Html(rendered).into_response()),
    )
}
