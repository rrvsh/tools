use std::sync::Arc;

mod content;
mod controllers;
mod models;
mod settings;
mod state;
mod views;

pub async fn serve() {
    let settings = settings::AppSettings::from_env();
    content::sync().unwrap_or_else(|err| panic!("failed to sync site content: {err}"));
    let documents = models::document::load_documents_from_dir(content::SITE_CONTENT_DIR);
    let state = Arc::new(state::AppState::new(documents));
    let listener = tokio::net::TcpListener::bind(&settings.addr).await.unwrap();
    let router = controllers::build_router(state, content::SITE_CONTENT_DIR, &settings.static_dir);
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
