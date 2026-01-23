use lib::Document;

#[derive(Clone)]
pub struct AppState {
    pub documents: Vec<Document>,
}

impl AppState {
    pub const fn new(documents: Vec<Document>) -> Self {
        Self { documents }
    }
}
