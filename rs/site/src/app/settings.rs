pub struct AppSettings {
    pub addr: String,
}

impl AppSettings {
    pub fn from_env() -> Self {
        let host = std::env::var("HOST").unwrap_or_else(|_| "0.0.0.0".to_string());
        let port = std::env::var("PORT").unwrap_or_else(|_| "8080".to_string());
        Self {
            addr: format!("{host}:{port}"),
        }
    }
}
