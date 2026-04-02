use crate::app::state::AppState;
use crate::app::views::{MonthGroup, base_template_github_url, current_commit_hash};
use askama::Template;
use axum::{
    extract::State,
    http::StatusCode,
    response::{Html, IntoResponse, Response},
};
use std::sync::Arc;

#[derive(Template)]
#[template(path = "index.html")]
struct IndexTemplate {
    months: Vec<MonthGroup>,
    base_template_url: String,
    commit_hash: String,
}

pub async fn get(State(state): State<Arc<AppState>>) -> Result<Response, StatusCode> {
    IndexTemplate {
        months: state.months.clone(),
        base_template_url: base_template_github_url(),
        commit_hash: current_commit_hash(),
    }
    .render()
    .map_or_else(
        |_| Err(StatusCode::INTERNAL_SERVER_ERROR),
        |rendered| Ok(Html(rendered).into_response()),
    )
}
