use std::sync::Arc;

pub mod routes;
pub mod settings;
pub mod state;

pub async fn serve() {
    let settings = settings::AppSettings::from_env();
    let documents = lib::load_documents_from_dir(&settings.content_dir);
    let state = Arc::new(state::AppState::new(documents));
    let listener = tokio::net::TcpListener::bind(&settings.addr).await.unwrap();
    let router = routes::build_router(state);
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
