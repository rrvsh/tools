use crate::app::state::AppState;
use crate::app::views::MonthGroup;
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
}

pub async fn get(State(state): State<Arc<AppState>>) -> Result<Response, StatusCode> {
    IndexTemplate {
        months: state.months.clone(),
    }
    .render()
    .map_or_else(
        |_| Err(StatusCode::INTERNAL_SERVER_ERROR),
        |rendered| Ok(Html(rendered).into_response()),
    )
}
