# Refactor Plan: From Axum to Pure Tokio HTTP Server

## Current Architecture Overview

**Dependencies to Replace:**
| Current | Purpose | Replacement |
|---------|---------|-------------|
| `axum 0.8.8` | HTTP routing, request handling | Custom tokio-based server |
| `askama 0.15.1` | HTML templating | Custom template engine |
| `tower-http 0.6.2` | Static file serving | Custom file server |
| `markdown 1.0.0` | Markdown to HTML | Keep or custom parser |
| `markdown-frontmatter 0.4.0` | YAML frontmatter parsing | Keep or custom parser |

**Current Routes:**
- `GET /` → Index page with article listings grouped by month
- `GET /{year}/{month}/{day}/{slug}` → Individual article page
- `GET /static/*` → Static files from `static_dir`
- `GET /assets/*` → Static files from `content_dir/assets`

**Data Flow:**
```
main.rs → serve()
    ↓
load_documents_from_dir() → Parse markdown files with YAML frontmatter
    ↓
AppState { months: Vec<MonthGroup>, articles_by_key: HashMap }
    ↓
Router with handlers for / and /{year}/{month}/{day}/{slug}
    ↓
Template rendering (Askama) → HTML response
```

## Phase 1: HTTP Server Core (Pure Tokio)

### 1.1 TCP Listener & Connection Handling
```rust
// New file: src/http/server.rs
use tokio::net::{TcpListener, TcpStream};

pub struct HttpServer {
    listener: TcpListener,
    handler: Arc<dyn RequestHandler>,
}

impl HttpServer {
    pub async fn bind(addr: &str) -> io::Result<Self>;
    pub async fn run(self) -> io::Result<()>;
    async fn handle_connection(stream: TcpStream, handler: Arc<dyn RequestHandler>);
}
```

**Key Decisions:**
- Use `tokio::net::TcpListener` for async networking
- Spawn a task per connection for concurrency
- Implement connection pooling/backpressure if needed
- Handle graceful shutdown via `tokio::signal::ctrl_c()`

### 1.2 HTTP Request Parsing
```rust
// New file: src/http/request.rs
pub struct Request {
    pub method: Method,          // GET, POST, etc.
    pub path: String,            // /2024/03/15/hello-world
    pub version: Version,        // HTTP/1.1
    pub headers: HashMap<String, String>,
    pub body: Option<Vec<u8>>,
}

pub enum Method { Get, Post, /* ... */ }

impl Request {
    pub fn parse(buffer: &[u8]) -> Result<(Self, usize), ParseError>;
    pub fn path_segments(&self) -> Vec<&str>;  // ["2024", "03", "15", "hello-world"]
}
```

**Implementation Notes:**
- Parse HTTP request line: `METHOD PATH HTTP/VERSION\r\n`
- Parse headers until empty line `\r\n\r\n`
- Support chunked transfer encoding if needed (not for this site)
- Handle buffer management for incomplete reads

### 1.3 HTTP Response Building
```rust
// New file: src/http/response.rs
pub struct Response {
    pub status: StatusCode,
    pub headers: HashMap<String, String>,
    pub body: Vec<u8>,
}

pub enum StatusCode {
    Ok = 200,
    NotFound = 404,
    InternalServerError = 500,
    // ...
}

impl Response {
    pub fn ok(body: impl Into<Body>) -> Self;
    pub fn html(content: &str) -> Self;
    pub fn not_found() -> Self;
    pub fn into_bytes(self) -> Vec<u8>;  // Serialize to HTTP response
}
```

### 1.4 Router Implementation
```rust
// New file: src/http/router.rs
pub struct Router {
    routes: Vec<Route>,
    state: Arc<AppState>,
}

struct Route {
    pattern: RoutePattern,
    handler: Box<dyn Handler>,
}

pub trait Handler: Send + Sync {
    fn handle(&self, req: Request, state: Arc<AppState>) -> Response;
}

impl Router {
    pub fn new(state: Arc<AppState>) -> Self;
    pub fn route(mut self, path: &str, handler: impl Handler) -> Self;
    pub fn route_param(mut self, pattern: &str, handler: impl Handler) -> Self;  // /:year/:month/:day/:slug
    pub fn match_request(&self, req: &Request) -> Option<&dyn Handler>;
}
```

**Route Matching Strategy:**
- Static routes: exact match (`/`, `/static/styles.css`)
- Parameter routes: pattern match (`/{year}/{month}/{day}/{slug}`)
- Wildcard routes: prefix match (`/static/*`)
- Priority: static > parameterized > wildcard

## Phase 2: Template Engine (Pure Rust)

### 2.1 Template System Design
```rust
// New file: src/template/mod.rs
pub trait Template {
    fn render(&self) -> Result<String, TemplateError>;
}

pub struct TemplateEngine {
    templates: HashMap<String, CompiledTemplate>,
}

struct CompiledTemplate {
    parts: Vec<TemplatePart>,
}

enum TemplatePart {
    Literal(String),           // Raw HTML
    Variable(String),          // {{ field_name }}
    Block(String, Vec<TemplatePart>),  // {% for x in y %}
    Include(String),           // {% extends "base.html" %}
}
```

### 2.2 Template Parsing
**Syntax to Support (Askama-compatible subset):**
- `{{ variable }}` - Variable interpolation
- `{% for item in items %}` - Loops
- `{% if condition %}` - Conditionals
- `{% extends "base.html" %}` - Template inheritance
- `{% block content %}` - Block overrides
- `{{ content | safe }}` - Mark as safe (no escaping)

**Parser Implementation:**
```rust
impl TemplateEngine {
    pub fn compile(template_str: &str) -> Result<CompiledTemplate, ParseError> {
        // Parse using state machine or regex
        // Handle nested blocks
        // Build AST of TemplatePart
    }
}
```

### 2.3 Template Rendering
```rust
impl CompiledTemplate {
    pub fn render(&self, context: &dyn TemplateContext) -> Result<String, RenderError> {
        let mut output = String::new();
        for part in &self.parts {
            match part {
                Literal(s) => output.push_str(s),
                Variable(name) => output.push_str(&context.get(name)?),
                Block(name, children) => self.render_block(name, children, context, &mut output)?,
            }
        }
        Ok(output)
    }
}
```

**Context Trait:**
```rust
pub trait TemplateContext {
    fn get(&self, field: &str) -> Result<String, ContextError>;
    fn get_iter(&self, field: &str) -> Result<Box<dyn Iterator<Item = &dyn TemplateContext>>, ContextError>;
}

// Derive macro or manual impl for structs
impl TemplateContext for IndexTemplate { ... }
impl TemplateContext for ArticleTemplate { ... }
```

## Phase 3: Static File Serving

### 3.1 File Server
```rust
// New file: src/http/static_file.rs
pub struct StaticFileServer {
    root: PathBuf,
    cache: Option<HashMap<PathBuf, CachedFile>>,
}

struct CachedFile {
    content: Vec<u8>,
    content_type: String,
    last_modified: SystemTime,
}

impl StaticFileServer {
    pub fn new(root: PathBuf, enable_cache: bool) -> Self;
    pub fn serve(&self, path: &str) -> Result<Response, StaticFileError>;
    fn guess_content_type(path: &str) -> &'static str;
    fn read_file(&self, path: &Path) -> io::Result<Vec<u8>>;
}
```

**Content Type Mapping:**
| Extension | Content-Type |
|-----------|--------------|
| .html | text/html |
| .css | text/css |
| .js | application/javascript |
| .ico | image/x-icon |
| .png | image/png |

### 3.2 Range Request Support (Optional)
For large static files, support HTTP Range requests for partial content delivery.

## Phase 4: Route Handlers Migration

### 4.1 Index Handler
```rust
// src/handlers/index.rs
pub struct IndexHandler;

impl Handler for IndexHandler {
    fn handle(&self, _req: Request, state: Arc<AppState>) -> Response {
        let template = IndexTemplate {
            months: state.months.clone(),
        };
        
        match template.render() {
            Ok(html) => Response::ok(html).with_content_type("text/html"),
            Err(_) => Response::internal_server_error(),
        }
    }
}
```

### 4.2 Article Handler
```rust
// src/handlers/article.rs
pub struct ArticleHandler;

impl Handler for ArticleHandler {
    fn handle(&self, req: Request, state: Arc<AppState>) -> Response {
        // Extract params from path: /{year}/{month}/{day}/{slug}
        let segments: Vec<&str> = req.path_segments();
        if segments.len() != 4 {
            return Response::not_found();
        }
        
        let year = segments[0].parse::<i32>().ok()?;
        let month = segments[1].parse::<u32>().ok()?;
        let day = segments[2].parse::<u32>().ok()?;
        let slug = segments[3].to_string();
        
        let key = (year, month, day, slug);
        let article = match state.articles_by_key.get(&key) {
            Some(a) => a,
            None => return Response::not_found(),
        };
        
        let template = ArticleTemplate {
            title: article.title.clone(),
            date: format_article_date(NaiveDate::from_ymd_opt(year, month, day)?),
            content: markdown_to_html(&article.content),
        };
        
        match template.render() {
            Ok(html) => Response::ok(html).with_content_type("text/html"),
            Err(_) => Response::internal_server_error(),
        }
    }
}
```

## Phase 5: Application Bootstrap

### 5.1 New app/mod.rs Structure
```rust
// src/app/mod.rs
pub mod handlers;
pub mod models;
pub mod settings;
pub mod state;
pub mod views;

use std::sync::Arc;
use crate::http::{HttpServer, Router};

pub async fn serve() {
    let settings = settings::AppSettings::from_env();
    let documents = models::document::load_documents_from_dir(&settings.content_dir);
    let state = Arc::new(state::AppState::new(documents));
    
    let router = Router::new(state.clone())
        .route("/", handlers::index::IndexHandler)
        .route("/{year}/{month}/{day}/{slug}", handlers::article::ArticleHandler)
        .nest_service("/static", StaticFileServer::new(&settings.static_dir))
        .nest_service("/assets", StaticFileServer::new(Path::new(&settings.content_dir).join("assets")));
    
    let server = HttpServer::bind(&settings.addr)
        .await
        .expect("Failed to bind address")
        .with_router(router);
    
    server.run().await.expect("Server error");
}
```

## Phase 6: Testing Strategy

### 6.1 HTTP Parsing Tests
- Valid/invalid request lines
- Header parsing edge cases
- Body content-length handling

### 6.2 Router Tests
- Static route matching
- Parameter extraction
- 404 handling

### 6.3 Template Tests
- Variable interpolation
- Loop rendering
- Block inheritance
- Escaping (XSS prevention)

### 6.4 Integration Tests
- Full request/response cycle
- Static file serving
- Article page rendering

## Implementation Timeline

| Phase | Description | Estimated Effort | Dependencies |
|-------|-------------|------------------|--------------|
| 1.1 | TCP listener & connection handling | 2-3 hours | tokio |
| 1.2 | HTTP request parsing | 4-6 hours | - |
| 1.3 | HTTP response building | 2-3 hours | - |
| 1.4 | Router implementation | 4-6 hours | 1.2, 1.3 |
| 2.1-2.3 | Template engine | 8-12 hours | - |
| 3.1 | Static file server | 2-3 hours | - |
| 4.1-4.2 | Route handlers | 2-3 hours | All above |
| 5.1 | Bootstrap integration | 1-2 hours | All above |
| 6.x | Testing | 4-6 hours | All above |
| **Total** | | **29-44 hours** | |

## Dependencies After Refactor

```toml
[dependencies]
# Keep these - too complex to rewrite
chrono = "0.4.43"           # Date/time handling
ignore = "0.4.25"           # Directory walking with gitignore
serde = "1.0.228"           # If keeping YAML frontmatter parsing
markdown = "1.0.0"          # Could write simple parser (~200 LOC)
markdown-frontmatter = "0.4.0"  # Could write simple YAML parser

# Core async runtime
tokio = { version = "1.49.0", features = ["full"] }

# Optional - might be useful but not required
# tempfile = "3.24.0"       # Only for tests
```

## Key Technical Challenges

### 1. HTTP/1.1 Persistence
- Implement `Connection: keep-alive` properly
- Handle request pipelining
- Connection timeout management

### 2. Buffer Management
- Avoid loading entire files into memory
- Stream large responses
- Handle backpressure

### 3. Template Safety
- Proper HTML escaping (XSS prevention)
- Safe filter for raw HTML insertion
- Block inheritance order

### 4. Error Handling
- Consistent error responses
- Proper HTTP status codes
- Graceful degradation

## Files to Create/Modify

### New Files (HTTP Stack)
```
src/http/mod.rs          # Public exports
src/http/server.rs       # TcpListener wrapper
src/http/request.rs      # Request parsing
src/http/response.rs     # Response building
src/http/router.rs       # Route matching
src/http/static_file.rs  # Static file serving
src/http/error.rs        # HTTP errors
```

### New Files (Template Engine)
```
src/template/mod.rs          # Public exports
src/template/parser.rs       # Template syntax parsing
src/template/compiler.rs     # Compile to AST
src/template/renderer.rs     # Render with context
src/template/context.rs      # Context trait
src/template/error.rs        # Template errors
```

### Modified Files
```
src/app/mod.rs           # Remove axum, use custom http
src/app/controllers/     # Rename to handlers, update trait bounds
templates/               # May need syntax tweaks (probably compatible)
Cargo.toml               # Remove axum, tower-http
```

## Alternative: Use Tower (Middle Ground)

If writing from scratch proves too complex, consider using just `tower` and `tower-service`:

```toml
[dependencies]
tower = { version = "0.5", default-features = false, features = ["util"] }
tokio = { version = "1", features = ["full"] }
```

This gives you:
- The `Service` trait abstraction
- Middleware layering
- Backpressure handling

While you still write:
- HTTP parsing
- Routing
- Response generation

This is a good middle ground between "from scratch" and "too much abstraction".

## Viability Assessment

**Pros of this approach:**
- Deep understanding of HTTP protocol
- Minimal dependencies
- Full control over performance characteristics
- No hidden magic - you own every line
- Excellent learning experience
- Can optimize specifically for your use case

**Cons/Challenges:**
- Security considerations (XSS, request parsing bugs)
- Need to handle edge cases (malformed requests, path traversal)
- Time investment (~30-40 hours)
- No ecosystem benefits (middleware, auth, etc.)
- Testing burden increases significantly

**Verdict:** Very viable for a personal blog. The requirements are simple:
- 2 dynamic routes
- Static file serving
- Basic templating
- No authentication, sessions, or complex middleware

The primary risk areas are:
1. HTTP parsing security (request smuggling, buffer overflows)
2. Template escaping (XSS)
3. Path traversal in static file serving

All are manageable with careful coding and thorough testing.

## Next Steps

1. **Start with Phase 1.1 & 1.2**: TCP listener + basic HTTP parsing
2. **Write integration tests early**: Capture current behavior with axum, verify parity
3. **Implement template engine**: Start with just variable interpolation, add loops/conditionals
4. **Port one route at a time**: Index first (simpler), then article
5. **Static file serving last**: It's mostly filesystem + content-type mapping

Would you like me to start implementing any specific phase?