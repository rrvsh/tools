mod app;

#[tokio::main]
async fn main() {
    let settings = app::settings::AppSettings::from_env();
    let app = app::build();
    let listener = tokio::net::TcpListener::bind(settings.addr).await.unwrap();
    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown_signal())
        .await
        .unwrap();
}

async fn shutdown_signal() {
    tokio::signal::ctrl_c()
        .await
        .expect("failed to install Ctrl+C handler");
}
