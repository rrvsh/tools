mod article;
mod index;
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
        .route("/reader", get(reader::get))
        .route("/{year}/{month}/{day}/{slug}", get(article::get))
        .with_state(state)
}
