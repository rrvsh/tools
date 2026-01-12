mod app;

#[tokio::main]
async fn main() {
    let settings = app::settings::AppSettings::from_env();
    let app = app::build();
    let listener = tokio::net::TcpListener::bind(settings.addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
