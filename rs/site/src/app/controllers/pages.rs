use askama::Template;
use axum::{
    http::StatusCode,
    response::{Html, IntoResponse, Response},
};

#[derive(Template)]
#[template(path = "page.html")]
struct PageTemplate {
    heading: &'static str,
}

fn render(heading: &'static str) -> Result<Response, StatusCode> {
    PageTemplate { heading }.render().map_or_else(
        |_| Err(StatusCode::INTERNAL_SERVER_ERROR),
        |rendered| Ok(Html(rendered).into_response()),
    )
}

pub async fn work() -> Result<Response, StatusCode> {
    render("work")
}

pub async fn posts() -> Result<Response, StatusCode> {
    render("posts")
}

pub async fn about() -> Result<Response, StatusCode> {
    render("about")
}
