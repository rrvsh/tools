use ignore::Walk;
use lib::Document;

pub mod routes;
pub mod settings;

pub async fn serve() {
    let settings = settings::AppSettings::from_env();
    load_files(&settings.content_dir);
    let listener = tokio::net::TcpListener::bind(&settings.addr).await.unwrap();
    let router = routes::build_router(settings);
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

fn load_files(content_dir: &str) {
    for result in Walk::new(content_dir) {
        match result {
            Ok(entry) => {
                if let Some(document) = Document::from_path(entry.path()) {
                    dbg!(document);
                }
            }
            Err(err) => println!("ERROR: {err}"),
        }
    }
}
