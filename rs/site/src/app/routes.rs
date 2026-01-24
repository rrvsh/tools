use crate::app::state::{AppState, MonthGroup};
use askama::Template;
use axum::{
    extract::{Path, State},
    http::{HeaderValue, StatusCode, header},
    response::{Html, IntoResponse, Response},
    routing::get,
};
use chrono::{Datelike, NaiveDate};
use markdown::to_html;
use rss::{ChannelBuilder, GuidBuilder, ItemBuilder};
use std::sync::Arc;

fn markdown_summary(content: &str, max_lines: usize) -> String {
    content
        .lines()
        .map(str::trim)
        .filter(|line| !line.is_empty())
        .take(max_lines)
        .collect::<Vec<_>>()
        .join("\n")
}

pub fn build_router(state: Arc<AppState>) -> axum::Router {
    axum::Router::new()
        .route("/", get(index_get))
        .route("/feed", get(feed_get))
        .route("/{year}/{month}/{day}/{slug}", get(article_get))
        .with_state(state)
}

#[derive(Template)]
#[template(path = "index.html")]
struct IndexTemplate {
    months: Vec<MonthGroup>,
}

pub async fn index_get(State(state): State<Arc<AppState>>) -> Result<Response, StatusCode> {
    IndexTemplate {
        months: state.months.clone(),
    }
    .render()
    .map_or_else(
        |_| Err(StatusCode::INTERNAL_SERVER_ERROR),
        |rendered| Ok(Html(rendered).into_response()),
    )
}

#[derive(Template)]
#[template(path = "article.html")]
struct ArticleTemplate {
    title: String,
    date: String,
    content: String,
}

fn format_article_date(date: NaiveDate) -> String {
    let day = date.day();
    let suffix = match day {
        11..=13 => "th",
        _ => match day % 10 {
            1 => "st",
            2 => "nd",
            3 => "rd",
            _ => "th",
        },
    };

    format!(
        "written on {}, the {day}{suffix} of {} {}",
        date.format("%A"),
        date.format("%B"),
        date.year()
    )
}

pub async fn article_get(
    Path((year, month, day, slug)): Path<(i32, u32, u32, String)>,
    State(state): State<Arc<AppState>>,
) -> Result<Response, StatusCode> {
    let requested_date = NaiveDate::from_ymd_opt(year, month, day).ok_or(StatusCode::NOT_FOUND)?;
    let document = state
        .articles_by_key
        .get(&(year, month, day, slug))
        .ok_or(StatusCode::NOT_FOUND)?;
    ArticleTemplate {
        title: document.title.clone(),
        date: format_article_date(requested_date),
        content: to_html(&document.content),
    }
    .render()
    .map_or_else(
        |_| Err(StatusCode::INTERNAL_SERVER_ERROR),
        |rendered| Ok(Html(rendered).into_response()),
    )
}

pub async fn feed_get(State(state): State<Arc<AppState>>) -> Result<Response, StatusCode> {
    let mut articles = state.articles_by_key.values().cloned().collect::<Vec<_>>();
    articles.sort_by(|left, right| {
        right
            .date
            .cmp(&left.date)
            .then_with(|| left.title.cmp(&right.title))
    });

    let items = articles
        .into_iter()
        .take(state.settings.rss_item_limit)
        .map(|article| {
            let link = format!("{}{}", state.settings.base_url, article.url);
            let summary = markdown_summary(&article.content, state.settings.rss_summary_lines);
            let html = markdown::to_html(&article.content);
            let pub_date = article
                .date
                .and_hms_opt(0, 0, 0)
                .map(|dt| dt.and_utc().to_rfc2822());

            let mut builder = ItemBuilder::default();
            builder.title(article.title);
            builder.link(link.clone());
            builder.guid(GuidBuilder::default().value(link).permalink(true).build());
            builder.description(summary);
            builder.content(Some(html));
            if let Some(pub_date) = pub_date {
                builder.pub_date(pub_date);
            }
            builder.build()
        })
        .collect::<Vec<_>>();

    let channel = ChannelBuilder::default()
        .title(state.settings.site_title.clone())
        .link(state.settings.base_url.clone())
        .description(state.settings.site_description.clone())
        .language(Some(state.settings.site_language.clone()))
        .items(items)
        .build();

    let mut response = channel.to_string().into_response();
    response.headers_mut().insert(
        header::CONTENT_TYPE,
        HeaderValue::from_static("application/rss+xml; charset=utf-8"),
    );
    Ok(response)
}

#[cfg(test)]
mod tests {
    use super::feed_get;
    use crate::app::settings::AppSettings;
    use crate::app::state::AppState;
    use axum::extract::State;
    use chrono::NaiveDate;
    use lib::Document;
    use rss::Channel;
    use std::sync::Arc;

    fn test_settings() -> AppSettings {
        AppSettings {
            addr: "127.0.0.1:0".to_string(),
            content_dir: "/tmp".to_string(),
            base_url: "https://rrv.sh".to_string(),
            site_title: "rrv.sh".to_string(),
            site_description: "Personal feed".to_string(),
            site_language: "en".to_string(),
            rss_item_limit: 50,
            rss_summary_lines: 5,
        }
    }

    fn doc(title: &str, slug: &str, date: NaiveDate, content: &str) -> Document {
        Document {
            title: title.to_string(),
            slug: slug.to_string(),
            date,
            content: content.to_string(),
        }
    }

    #[tokio::test]
    async fn feed_includes_summary_and_content() {
        let documents = vec![doc(
            "Post",
            "post",
            NaiveDate::from_ymd_opt(2025, 1, 2).unwrap(),
            "Line one\n\nLine two\nLine three\nLine four\nLine five\nLine six",
        )];
        let state = AppState::new(documents, test_settings());
        let response = feed_get(State(Arc::new(state))).await.unwrap();
        let bytes = axum::body::to_bytes(response.into_body(), usize::MAX)
            .await
            .unwrap();
        let channel = Channel::read_from(bytes.as_ref()).unwrap();
        let item = &channel.items()[0];

        assert_eq!(
            item.description().unwrap(),
            "Line one\nLine two\nLine three\nLine four\nLine five"
        );
        assert!(item.content().unwrap().contains("Line one"));
        assert!(item.link().unwrap().starts_with("https://rrv.sh/"));
    }

    #[tokio::test]
    async fn feed_orders_newest_first() {
        let documents = vec![
            doc(
                "Older",
                "older",
                NaiveDate::from_ymd_opt(2024, 12, 1).unwrap(),
                "Older post",
            ),
            doc(
                "Newer",
                "newer",
                NaiveDate::from_ymd_opt(2025, 1, 2).unwrap(),
                "Newer post",
            ),
        ];
        let state = AppState::new(documents, test_settings());
        let response = feed_get(State(Arc::new(state))).await.unwrap();
        let bytes = axum::body::to_bytes(response.into_body(), usize::MAX)
            .await
            .unwrap();
        let channel = Channel::read_from(bytes.as_ref()).unwrap();
        let titles = channel
            .items()
            .iter()
            .map(|item| item.title().unwrap())
            .collect::<Vec<_>>();

        assert_eq!(titles, vec!["Newer", "Older"]);
    }
}
