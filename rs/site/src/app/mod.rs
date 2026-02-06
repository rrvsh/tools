use std::sync::Arc;

mod controllers;
mod models;
mod settings;
mod state;
mod views;

pub async fn serve() {
    let settings = settings::AppSettings::from_env();
    let documents = models::document::load_documents_from_dir(&settings.content_dir);
    let state = Arc::new(state::AppState::new(documents));
    let listener = tokio::net::TcpListener::bind(&settings.addr).await.unwrap();
    let router = controllers::build_router(state, &settings.content_dir, &settings.static_dir);
    axum::serve(listener, router)
        .with_graceful_shutdown(shutdown_signal())
        .await
        .unwrap();
}

async fn shutdown_signal() {
    tokio::signal::ctrl_c()
        .await
        .expect("failed to install Ctrl+C handler");
}
