use askama::Template;
use axum::{
    Router,
    http::StatusCode,
    response::{Html, IntoResponse, Response},
    routing::get,
};

#[derive(Template)]
#[template(path = "hello.html")]
struct HelloTemplate {
    name: String,
}

#[tokio::main]
async fn main() {
    let host = "0.0.0.0";
    let port = 3000;
    let addr = format!("{host}:{port}");
    let listener = tokio::net::TcpListener::bind(addr)
        .await
        .expect("Error binding to port {port}");

    let app = Router::new().route("/hello", get(hello_get));
    axum::serve(listener, app).await.unwrap();
}

async fn hello_get() -> Result<Response, StatusCode> {
    HelloTemplate {
        name: "world".to_string(),
    }
    .render()
    .map_or_else(
        |_| Err(StatusCode::INTERNAL_SERVER_ERROR),
        |rendered| Ok(Html(rendered).into_response()),
    )
}
