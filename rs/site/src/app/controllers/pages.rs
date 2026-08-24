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
#[template(path = "page.html")]
struct WorkTemplate {
    heading: &'static str,
}

#[derive(Template)]
#[template(path = "about.html")]
struct AboutTemplate;

#[derive(Template)]
#[template(path = "posts.html")]
struct PostsTemplate {
    months: Vec<MonthGroup>,
}

pub async fn work() -> Result<Response, StatusCode> {
    WorkTemplate { heading: "work" }.render().map_or_else(
        |_| Err(StatusCode::INTERNAL_SERVER_ERROR),
        |rendered| Ok(Html(rendered).into_response()),
    )
}

pub async fn posts(State(state): State<Arc<AppState>>) -> Result<Response, StatusCode> {
    PostsTemplate {
        months: state.months.clone(),
    }
    .render()
    .map_or_else(
        |_| Err(StatusCode::INTERNAL_SERVER_ERROR),
        |rendered| Ok(Html(rendered).into_response()),
    )
}

pub async fn about() -> Result<Response, StatusCode> {
    AboutTemplate.render().map_or_else(
        |_| Err(StatusCode::INTERNAL_SERVER_ERROR),
        |rendered| Ok(Html(rendered).into_response()),
    )
}
