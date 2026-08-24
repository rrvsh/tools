mod article;
mod index;
mod pages;
mod reader;

use crate::app::state::AppState;
use axum::routing::get;
use std::path::PathBuf;
use std::sync::Arc;
use tower_http::services::ServeDir;

pub fn build_router(state: Arc<AppState>, content_dir: &str, static_dir: &str) -> axum::Router {
    let static_dir = PathBuf::from(static_dir);
    let assets_dir = PathBuf::from(content_dir).join("assets");

    axum::Router::new()
        .nest_service("/static", ServeDir::new(static_dir))
        .nest_service("/assets", ServeDir::new(assets_dir))
        .route("/", get(index::get))
        .route("/work", get(pages::work))
        .route("/posts", get(pages::posts))
        .route("/about", get(pages::about))
        .route("/reader", get(reader::get))
        .route("/{year}/{month}/{day}/{slug}", get(article::get))
        .with_state(state)
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::{
        body::{Body, to_bytes},
        http::{Request, StatusCode},
    };
    use tower::ServiceExt;

    async fn assert_page(path: &str, heading: &str) {
        let state = Arc::new(AppState::new(Vec::new()));
        let response = build_router(state, "unused", "unused")
            .oneshot(Request::get(path).body(Body::empty()).unwrap())
            .await
            .unwrap();

        assert_eq!(response.status(), StatusCode::OK);
        let body = to_bytes(response.into_body(), usize::MAX).await.unwrap();
        let body = String::from_utf8(body.to_vec()).unwrap();
        assert!(body.contains(&format!("<h1>{heading}</h1>")));
    }

    #[tokio::test]
    async fn work_page_returns_its_heading() {
        assert_page("/work", "work").await;
    }

    #[tokio::test]
    async fn posts_page_returns_its_heading() {
        assert_page("/posts", "posts").await;
    }

    #[tokio::test]
    async fn about_page_returns_its_heading() {
        assert_page("/about", "about").await;
    }
}
