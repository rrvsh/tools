use askama::Template;
use axum::{
    http::StatusCode,
    response::{Html, IntoResponse, Response},
    routing::get,
};

pub fn build_router() -> axum::Router {
    axum::Router::new().route("/", get(hello))
}

#[derive(Template)]
#[template(path = "hello.html")]
struct HelloTemplate {
    name: String,
}

pub async fn hello() -> Result<Response, StatusCode> {
    HelloTemplate {
        name: "world".to_string(),
    }
    .render()
    .map_or_else(
        |_| Err(StatusCode::INTERNAL_SERVER_ERROR),
        |rendered| Ok(Html(rendered).into_response()),
    )
}
