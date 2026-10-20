use askama::Template;
use axum::{
    http::StatusCode,
    response::{Html, IntoResponse, Response},
};

#[derive(Template)]
#[template(path = "ascii.html")]
struct AsciiTemplate {}

pub async fn get() -> Result<Response, StatusCode> {
    AsciiTemplate {}.render().map_or_else(
        |_| Err(StatusCode::INTERNAL_SERVER_ERROR),
        |rendered| Ok(Html(rendered).into_response()),
    )
}
