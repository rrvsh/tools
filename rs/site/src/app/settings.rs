#[derive(Clone)]
pub struct AppSettings {
    pub addr: String,
    pub content_dir: String,
    pub base_url: String,
    pub site_title: String,
    pub site_description: String,
    pub site_language: String,
    pub rss_item_limit: usize,
    pub rss_summary_lines: usize,
}

impl AppSettings {
    pub fn from_env() -> Self {
        let host = std::env::var("HOST").unwrap_or_else(|_| "0.0.0.0".to_string());
        let port = std::env::var("PORT").unwrap_or_else(|_| "8080".to_string());
        let content_dir = std::env::var("SITE_CONTENT_DIR")
            .unwrap_or_else(|_| "/Users/rafiq/publish".to_string());
        let base_url =
            std::env::var("SITE_BASE_URL").unwrap_or_else(|_| "https://rrv.sh".to_string());
        let site_title = std::env::var("SITE_TITLE").unwrap_or_else(|_| "rrv.sh".to_string());
        let site_description =
            std::env::var("SITE_DESCRIPTION").unwrap_or_else(|_| "Personal feed".to_string());
        let site_language = std::env::var("SITE_LANGUAGE").unwrap_or_else(|_| "en".to_string());
        let rss_item_limit = std::env::var("RSS_ITEM_LIMIT")
            .ok()
            .and_then(|value| value.parse().ok())
            .unwrap_or(50);
        let rss_summary_lines = std::env::var("RSS_SUMMARY_LINES")
            .ok()
            .and_then(|value| value.parse().ok())
            .unwrap_or(5);
        Self {
            addr: format!("{host}:{port}"),
            content_dir,
            base_url,
            site_title,
            site_description,
            site_language,
            rss_item_limit,
            rss_summary_lines,
        }
    }
}
