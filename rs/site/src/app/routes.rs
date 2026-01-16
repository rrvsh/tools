use askama::Template;
use axum::{
    extract::Path,
    http::StatusCode,
    response::{Html, IntoResponse, Response},
    routing::get,
};

pub fn build_router() -> axum::Router {
    axum::Router::new()
        .route("/", get(index_get))
        .route("/blog", get(blog_index_get))
        .route("/{year}/{month}/{day}/{slug}", get(article_get))
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

#[derive(Template)]
#[template(path = "article.html")]
struct ArticleTemplate {
    content: String,
}

pub async fn article_get(
    Path((year, month, day, slug)): Path<(i32, i32, i32, String)>,
) -> Result<Response, StatusCode> {
    let content = format!("{year}-{month}-{day}-{slug}");
    ArticleTemplate { content }.render().map_or_else(
        |_| Err(StatusCode::INTERNAL_SERVER_ERROR),
        |rendered| Ok(Html(rendered).into_response()),
    )
}
