use axum::routing::get;

pub mod routes;
pub mod settings;

pub fn build() -> axum::Router {
    axum::Router::new().route("/", get(routes::hello))
}
