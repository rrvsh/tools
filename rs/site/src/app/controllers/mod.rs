mod article;
mod index;

use crate::app::state::AppState;
use axum::routing::get;
use std::sync::Arc;

pub fn build_router(state: Arc<AppState>) -> axum::Router {
    axum::Router::new()
        .route("/", get(index::get))
        .route("/{year}/{month}/{day}/{slug}", get(article::get))
        .with_state(state)
}
