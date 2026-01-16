pub mod routes;
pub mod settings;

pub async fn serve() {
    let settings = settings::AppSettings::from_env();
    let listener = tokio::net::TcpListener::bind(settings.addr).await.unwrap();
    let router = routes::build_router();
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
