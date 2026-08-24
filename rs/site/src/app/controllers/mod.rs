mod article;
mod index;
mod pages;

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
        .route("/posts", get(pages::posts))
        .route("/about", get(pages::about))
        .route("/{year}/{month}/{day}/{slug}", get(article::get))
        .with_state(state)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::app::models::document::Document;
    use axum::{
        body::{Body, to_bytes},
        http::{Request, StatusCode},
    };
    use chrono::NaiveDate;
    use tower::ServiceExt;

    fn state_with_posts() -> Arc<AppState> {
        Arc::new(AppState::new(vec![
            Document {
                title: "New post".to_string(),
                slug: "new-post".to_string(),
                date: NaiveDate::from_ymd_opt(2026, 8, 24).unwrap(),
                content: String::new(),
            },
            Document {
                title: "Older post".to_string(),
                slug: "older-post".to_string(),
                date: NaiveDate::from_ymd_opt(2025, 7, 1).unwrap(),
                content: String::new(),
            },
        ]))
    }

    async fn response_body(state: Arc<AppState>, path: &str) -> String {
        let response = build_router(state, "unused", "unused")
            .oneshot(Request::get(path).body(Body::empty()).unwrap())
            .await
            .unwrap();

        assert_eq!(response.status(), StatusCode::OK);
        let body = to_bytes(response.into_body(), usize::MAX).await.unwrap();
        String::from_utf8(body.to_vec()).unwrap()
    }

    #[tokio::test]
    async fn home_links_to_about_and_posts_without_moved_content() {
        let body = response_body(state_with_posts(), "/").await;

        assert!(body.contains("<a href=\"/about\">about</a>"));
        assert!(body.contains("<a href=\"/posts\">posts</a>"));
        assert!(!body.contains("hi! i'm rafiq"));
        assert!(!body.contains("New post"));
        assert!(!body.contains("Older post"));
    }

    #[tokio::test]
    async fn about_page_contains_the_introduction() {
        let body = response_body(state_with_posts(), "/about").await;

        assert!(body.contains("<h1>about</h1>"));
        assert!(body.contains("hi! i'm rafiq (@rrvsh on various platforms)"));
        assert!(body.contains("href=\"https://github.com/rrvsh\""));
    }

    #[tokio::test]
    async fn posts_page_contains_the_complete_monthly_archive() {
        let body = response_body(state_with_posts(), "/posts").await;

        assert!(body.contains("<h1>posts</h1>"));
        assert!(body.contains("August 2026"));
        assert!(body.contains("<a href=\"/2026/08/24/new-post\">New post</a>"));
        assert!(body.contains("July 2025"));
        assert!(body.contains("<a href=\"/2025/07/01/older-post\">Older post</a>"));
    }
}
