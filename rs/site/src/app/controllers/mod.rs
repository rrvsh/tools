mod article;
mod index;

use crate::app::state::AppState;
use axum::routing::get;
use std::path::PathBuf;
use std::sync::Arc;
use tower_http::services::ServeDir;

pub fn build_router(state: Arc<AppState>, content_dir: &str) -> axum::Router {
    let static_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("static");
    let assets_dir = PathBuf::from(content_dir).join("assets");

    axum::Router::new()
        .nest_service("/static", ServeDir::new(static_dir))
        .nest_service("/assets", ServeDir::new(assets_dir))
        .route("/", get(index::get))
        .route("/{year}/{month}/{day}/{slug}", get(article::get))
        .with_state(state)
}
