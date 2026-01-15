use askama::Template;
use axum::{
    http::StatusCode,
    response::{Html, IntoResponse, Response},
    routing::get,
};

pub fn build_router() -> axum::Router {
    axum::Router::new()
        .route("/", get(index_get))
        .route("/blog", get(blog_index_get))
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

#[derive(Template)]
#[template(path = "blog/index.html")]
struct BlogIndexTemplate {}

pub async fn blog_index_get() -> Result<Response, StatusCode> {
    BlogIndexTemplate {}.render().map_or_else(
        |_| Err(StatusCode::INTERNAL_SERVER_ERROR),
        |rendered| Ok(Html(rendered).into_response()),
    )
}
