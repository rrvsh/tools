use std::path::Path;

pub fn is_markdown<P: AsRef<Path>>(path: P) -> bool {
    let path = path.as_ref();
    path.is_file() && path.extension().and_then(|osstr| osstr.to_str()) == Some("md")
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs::File;
    use tempfile::tempdir;

    #[test]
    fn is_markdown_success() {
        let dir = tempdir().unwrap();
        let file_path = dir.path().join("my-temporary-note.md");
        let _ = File::create(&file_path).unwrap();
        assert!(is_markdown(file_path));
    }

    #[test]
    fn is_markdown_failure_not_markdown() {
        let dir = tempdir().unwrap();
        let file_path = dir.path().join("my-temporary-note.txt");
        let _ = File::create(&file_path).unwrap();
        assert!(!is_markdown(file_path));
    }

    #[test]
    fn is_markdown_failure_not_file() {
        let dir = tempdir().unwrap();
        let file_path = dir.path();
        assert!(!is_markdown(file_path));
    }
}
