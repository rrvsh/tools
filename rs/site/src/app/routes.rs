use crate::app::settings::AppSettings;
use askama::Template;
use axum::{
    extract::{Path, State},
    http::StatusCode,
    response::{Html, IntoResponse, Response},
    routing::get,
};
use ignore::{DirEntry, WalkBuilder};
use markdown::to_html;
use serde::Deserialize;
use std::fs::read_to_string;

pub fn build_router(settings: AppSettings) -> axum::Router {
    axum::Router::new()
        .route("/", get(index_get))
        .route("/blog", get(blog_index_get))
        .route("/{year}/{month}/{day}/{slug}", get(article_get))
        .with_state(settings)
}

#[derive(Template)]
#[template(path = "index.html")]
struct IndexTemplate {}

pub async fn index_get() -> Result<Response, StatusCode> {
    IndexTemplate {}.render().map_or_else(
        |_| Err(StatusCode::INTERNAL_SERVER_ERROR),
        |rendered| Ok(Html(rendered).into_response()),
    )
}

#[derive(Template)]
#[template(path = "blog/index.html")]
struct BlogIndexTemplate {}

pub async fn blog_index_get() -> Result<Response, StatusCode> {
    BlogIndexTemplate {}.render().map_or_else(
        |_| Err(StatusCode::INTERNAL_SERVER_ERROR),
        |rendered| Ok(Html(rendered).into_response()),
    )
}

#[derive(Template)]
#[template(path = "article.html")]
struct ArticleTemplate {
    content: String,
}

#[derive(Deserialize)]
struct ArticleFrontmatter {
    slug: String,
}

fn is_requested_article(entry: &DirEntry, slug: &str) -> bool {
    let file_extension = entry
        .path()
        .extension()
        .map(|osstr| osstr.to_str().expect("Invalid UTF-8!"));
    if Some("md") == file_extension {
        let file_content = read_to_string(entry.path()).expect("Error reading file to string!");
        let (frontmatter, _) = markdown_frontmatter::parse::<ArticleFrontmatter>(&file_content)
            .expect("Error parsing frontmatter!");
        frontmatter.slug == slug
    } else {
        false
    }
}

fn get_first_file_path_by_slug(folder_path: &str, slug: &str) -> Option<String> {
    let matching_entries = WalkBuilder::new(folder_path)
        .max_depth(Some(1))
        .build()
        .filter_map(|entry| entry.ok().filter(|entry| is_requested_article(entry, slug)))
        .collect::<Vec<DirEntry>>();
    if matching_entries.len() == 1 {
        Some(
            matching_entries
                .first()
                .expect("Error getting dir entry!")
                .path()
                .to_str()
                .expect("Invalid UTF-8")
                .to_string(),
        )
    } else {
        None
    }
}

pub async fn article_get(
    Path((year, month, day, slug)): Path<(i32, i32, i32, String)>,
    State(settings): State<AppSettings>,
) -> Result<Response, StatusCode> {
    let AppSettings { content_dir, .. } = settings;
    let folder_path = format!("{content_dir}/{year}/{month}/{day}");
    get_first_file_path_by_slug(&folder_path, &slug).map_or_else(
        || Err(StatusCode::NOT_FOUND),
        |file_path| {
            let file_content = read_to_string(file_path).expect("Error reading file!");
            let (_, body) = markdown_frontmatter::parse::<ArticleFrontmatter>(&file_content)
                .expect("Error parsing frontmatter!");
            ArticleTemplate {
                content: to_html(body),
            }
            .render()
            .map_or_else(
                |_| Err(StatusCode::INTERNAL_SERVER_ERROR),
                |rendered| Ok(Html(rendered).into_response()),
            )
        },
    )
}
