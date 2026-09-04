use axum::{
    body::Bytes,
    extract::DefaultBodyLimit,
    http::{HeaderMap, StatusCode},
    routing::{MethodRouter, post},
};
use base64::{Engine as _, engine::general_purpose::STANDARD};
use ed25519_dalek::{Signature, Verifier, VerifyingKey};
use std::path::{Path, PathBuf};

pub const TRIGGER_PATH: &str = "/var/lib/site/.content-refresh-request";
const SIGNATURE_HEADER: &str = "x-site-content-signature";
const PUBLIC_KEY: [u8; 32] = [
    228, 26, 61, 101, 116, 193, 69, 165, 231, 68, 2, 5, 58, 191, 175, 74, 196, 171, 50, 233, 242,
    188, 185, 51, 165, 198, 40, 8, 24, 47, 60, 40,
];

pub fn route<S>(trigger_path: PathBuf) -> MethodRouter<S>
where
    S: Clone + Send + Sync + 'static,
{
    route_with_public_key(trigger_path, PUBLIC_KEY)
}

fn route_with_public_key<S>(trigger_path: PathBuf, public_key: [u8; 32]) -> MethodRouter<S>
where
    S: Clone + Send + Sync + 'static,
{
    post(move |headers: HeaderMap, body: Bytes| {
        let trigger_path = trigger_path.clone();
        async move { handle(&headers, &body, &trigger_path, &public_key).await }
    })
    .layer(DefaultBodyLimit::max(40))
}

async fn handle(
    headers: &HeaderMap,
    body: &[u8],
    trigger_path: &Path,
    public_key: &[u8; 32],
) -> StatusCode {
    if body.len() != 40
        || !body
            .iter()
            .all(|byte| byte.is_ascii_hexdigit() && !byte.is_ascii_uppercase())
    {
        return StatusCode::BAD_REQUEST;
    }

    let Some(signature) = headers
        .get(SIGNATURE_HEADER)
        .and_then(|value| value.to_str().ok())
    else {
        return StatusCode::UNAUTHORIZED;
    };
    let Ok(signature_bytes) = STANDARD.decode(signature) else {
        return StatusCode::UNAUTHORIZED;
    };
    if STANDARD.encode(&signature_bytes) != signature {
        return StatusCode::UNAUTHORIZED;
    }
    let Ok(signature) = Signature::from_slice(&signature_bytes) else {
        return StatusCode::UNAUTHORIZED;
    };
    let Ok(public_key) = VerifyingKey::from_bytes(public_key) else {
        return StatusCode::UNAUTHORIZED;
    };
    if public_key.verify(body, &signature).is_err() {
        return StatusCode::UNAUTHORIZED;
    }

    if tokio::fs::write(trigger_path, body).await.is_err() {
        return StatusCode::INTERNAL_SERVER_ERROR;
    }

    StatusCode::ACCEPTED
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::{
        Router,
        body::{Body, to_bytes},
        http::Request,
    };
    use ed25519_dalek::{Signer, SigningKey};
    use tempfile::tempdir;
    use tower::ServiceExt;

    const TEST_SHA: &str = "0123456789abcdef0123456789abcdef01234567";
    const TEST_SIGNING_KEY: [u8; 32] = [
        88, 198, 31, 42, 100, 126, 225, 20, 25, 35, 117, 233, 44, 14, 91, 67, 65, 130, 82, 82, 249,
        79, 167, 169, 34, 197, 239, 88, 43, 138, 107, 188,
    ];

    fn signed_request(body: &str) -> Request<Body> {
        let signature = SigningKey::from_bytes(&TEST_SIGNING_KEY).sign(body.as_bytes());
        Request::post("/webhooks/site-content")
            .header(SIGNATURE_HEADER, STANDARD.encode(signature.to_bytes()))
            .body(Body::from(body.to_owned()))
            .unwrap()
    }

    fn test_router(trigger_path: PathBuf) -> Router {
        let public_key = SigningKey::from_bytes(&TEST_SIGNING_KEY)
            .verifying_key()
            .to_bytes();
        Router::new().route(
            "/webhooks/site-content",
            route_with_public_key(trigger_path, public_key),
        )
    }

    #[tokio::test]
    async fn accepts_a_valid_signed_sha_and_writes_the_trigger() {
        let directory = tempdir().unwrap();
        let trigger_path = directory.path().join("trigger");
        let response = test_router(trigger_path.clone())
            .oneshot(signed_request(TEST_SHA))
            .await
            .unwrap();

        assert_eq!(response.status(), StatusCode::ACCEPTED);
        assert!(
            to_bytes(response.into_body(), usize::MAX)
                .await
                .unwrap()
                .is_empty()
        );
        assert_eq!(
            tokio::fs::read_to_string(trigger_path).await.unwrap(),
            TEST_SHA
        );
    }

    #[tokio::test]
    async fn rejects_malformed_bodies_without_writing_the_trigger() {
        for body in [
            "0123456789abcdef0123456789abcdef0123456",
            "0123456789abcdef0123456789abcdef0123456g",
            "0123456789ABCDEF0123456789abcdef01234567",
        ] {
            let directory = tempdir().unwrap();
            let trigger_path = directory.path().join("trigger");
            let response = test_router(trigger_path.clone())
                .oneshot(signed_request(body))
                .await
                .unwrap();

            assert_eq!(response.status(), StatusCode::BAD_REQUEST);
            assert!(!trigger_path.exists());
        }
    }

    #[tokio::test]
    async fn rejects_missing_malformed_and_invalid_signatures_without_writing() {
        let directory = tempdir().unwrap();
        let trigger_path = directory.path().join("trigger");

        for request in [
            Request::post("/webhooks/site-content")
                .body(Body::from(TEST_SHA))
                .unwrap(),
            Request::post("/webhooks/site-content")
                .header(SIGNATURE_HEADER, "not-base64")
                .body(Body::from(TEST_SHA))
                .unwrap(),
            Request::post("/webhooks/site-content")
                .header(SIGNATURE_HEADER, STANDARD.encode([0; 64]))
                .body(Body::from(TEST_SHA))
                .unwrap(),
        ] {
            let response = test_router(trigger_path.clone())
                .oneshot(request)
                .await
                .unwrap();
            assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
            assert!(!trigger_path.exists());
        }
    }

    #[tokio::test]
    async fn rejects_noncanonical_and_oversized_requests() {
        let directory = tempdir().unwrap();
        let trigger_path = directory.path().join("trigger");
        let signature = SigningKey::from_bytes(&TEST_SIGNING_KEY).sign(TEST_SHA.as_bytes());
        let unpadded = STANDARD
            .encode(signature.to_bytes())
            .trim_end_matches('=')
            .to_owned();
        let noncanonical = Request::post("/webhooks/site-content")
            .header(SIGNATURE_HEADER, unpadded)
            .body(Body::from(TEST_SHA))
            .unwrap();
        let oversized = Request::post("/webhooks/site-content")
            .body(Body::from("0".repeat(41)))
            .unwrap();

        let response = test_router(trigger_path.clone())
            .clone()
            .oneshot(noncanonical)
            .await
            .unwrap();
        assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
        let response = test_router(trigger_path.clone())
            .oneshot(oversized)
            .await
            .unwrap();
        assert_eq!(response.status(), StatusCode::PAYLOAD_TOO_LARGE);
        assert!(!trigger_path.exists());
    }

    #[tokio::test]
    async fn returns_500_when_the_trigger_write_fails() {
        let directory = tempdir().unwrap();
        let response = test_router(directory.path().join("missing/trigger"))
            .oneshot(signed_request(TEST_SHA))
            .await
            .unwrap();

        assert_eq!(response.status(), StatusCode::INTERNAL_SERVER_ERROR);
    }
}
