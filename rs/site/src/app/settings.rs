#[derive(Clone)]
pub struct AppSettings {
    pub addr: String,
    pub content_dir: String,
    pub static_dir: String,
}

impl AppSettings {
    pub fn from_env() -> Self {
        let host = std::env::var("HOST").unwrap_or_else(|_| "0.0.0.0".to_string());
        let port = std::env::var("PORT").unwrap_or_else(|_| "8080".to_string());
        let content_dir = std::env::var("SITE_CONTENT_DIR")
            .unwrap_or_else(|_| "/Users/rafiq/publish".to_string());
        let static_dir = std::env::var("STATIC_DIR")
            .unwrap_or_else(|_| format!("{}/static", env!("CARGO_MANIFEST_DIR")));
        Self {
            addr: format!("{host}:{port}"),
            content_dir,
            static_dir,
        }
    }
}
