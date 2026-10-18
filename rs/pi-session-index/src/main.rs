use std::collections::{HashMap, HashSet};
use std::env;
use std::fs::{self, File, OpenOptions};
use std::io::{BufRead, BufReader, Read, Seek, SeekFrom};
use std::path::{Path, PathBuf};
use std::time::{Instant, UNIX_EPOCH};

use anyhow::{Context, Result, bail};
use chrono::DateTime;
use rayon::prelude::*;
use rusqlite::{Connection, params};
use serde::{Deserialize, Serialize};

#[cfg(not(unix))]
compile_error!("pi-session-index currently supports Unix platforms only");

const SCHEMA_VERSION: i64 = 3;
const FINGERPRINT_BYTES: usize = 4096;

#[derive(Debug)]
struct Args {
    sessions_dir: PathBuf,
    cache_path: Option<PathBuf>,
    output: Output,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Output {
    Summary,
    Json,
    Ndjson,
}

#[derive(Clone, Debug)]
struct Candidate {
    path: PathBuf,
    size: u64,
    mtime_ns: i64,
    file_id: String,
    ctime_ns: i64,
    prefix_hash: String,
    tail_hash: String,
}

#[derive(Clone, Debug, Deserialize)]
struct EntryKind {
    #[serde(rename = "type")]
    kind: Option<String>,
}

#[derive(Clone, Debug, Deserialize)]
struct Entry {
    #[serde(rename = "type")]
    kind: Option<String>,
    id: Option<String>,
    timestamp: Option<serde_json::Value>,
    cwd: Option<String>,
    #[serde(rename = "parentSession")]
    parent_session: Option<String>,
    name: Option<String>,
    message: Option<Message>,
}

#[derive(Clone, Debug, Deserialize)]
struct Message {
    role: Option<String>,
    content: Option<Content>,
    timestamp: Option<serde_json::Value>,
}

#[derive(Clone, Debug, Deserialize)]
#[serde(untagged)]
enum Content {
    Text(String),
    Blocks(Vec<Block>),
    Other(serde_json::Value),
}

#[derive(Clone, Debug, Deserialize)]
struct Block {
    #[serde(rename = "type")]
    kind: Option<String>,
    text: Option<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
struct SessionInfo {
    path: String,
    id: String,
    cwd: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    name: Option<String>,
    #[serde(rename = "parentSessionPath", skip_serializing_if = "Option::is_none")]
    parent_session_path: Option<String>,
    #[serde(rename = "createdMs")]
    created_ms: i64,
    #[serde(rename = "modifiedMs")]
    modified_ms: i64,
    #[serde(rename = "messageCount")]
    message_count: u64,
    #[serde(rename = "firstMessage")]
    first_message: String,
    #[serde(rename = "allMessagesText")]
    all_messages_text: String,
}

#[derive(Debug, Serialize)]
struct Summary {
    sessions: usize,
    candidates: usize,
    cache_hits: usize,
    parsed: usize,
    invalid: usize,
    elapsed_ms: u128,
    inventory_ms: u128,
    cache_load_ms: u128,
    parse_ms: u128,
    cache_write_ms: u128,
    search_text_bytes: usize,
}

fn main() -> Result<()> {
    let args = parse_args()?;
    let started = Instant::now();

    let inventory_started = Instant::now();
    let mut candidates = discover_candidates(&args.sessions_dir)?;
    candidates.sort_by(|left, right| {
        right
            .mtime_ns
            .cmp(&left.mtime_ns)
            .then_with(|| right.path.file_name().cmp(&left.path.file_name()))
    });
    let inventory_ms = inventory_started.elapsed().as_millis();

    let cache_started = Instant::now();
    let mut connection = match &args.cache_path {
        Some(path) => Some(open_cache(path)?),
        None => None,
    };
    let mut cached = match connection.as_ref() {
        Some(connection) => load_cache(connection)?,
        None => HashMap::new(),
    };
    let cache_load_ms = cache_started.elapsed().as_millis();

    let mut cache_hits = 0;
    let mut infos_by_path = HashMap::with_capacity(candidates.len());
    let mut misses = Vec::new();
    for candidate in &candidates {
        let key = candidate.path.to_string_lossy();
        match cached.remove(key.as_ref()) {
            Some((cached_candidate, info)) if candidate_matches(candidate, &cached_candidate) => {
                cache_hits += 1;
                infos_by_path.insert(candidate.path.clone(), info);
            }
            _ => misses.push(candidate.clone()),
        }
    }

    let parse_started = Instant::now();
    let parsed: Vec<(Candidate, Option<SessionInfo>)> = misses
        .into_par_iter()
        .map(|candidate| parse_session(&candidate).map(|info| (candidate, info)))
        .collect::<Result<_>>()?;
    let parse_ms = parse_started.elapsed().as_millis();

    let parsed_count = parsed.len();
    let invalid = parsed.iter().filter(|(_, info)| info.is_none()).count();
    let cache_write_started = Instant::now();
    if let Some(connection) = connection.as_mut() {
        write_cache(connection, &candidates, &parsed)?;
    }
    let cache_write_ms = cache_write_started.elapsed().as_millis();

    for (candidate, info) in parsed {
        if let Some(info) = info {
            infos_by_path.insert(candidate.path, info);
        }
    }
    let mut sessions: Vec<SessionInfo> = candidates
        .iter()
        .filter_map(|candidate| infos_by_path.remove(&candidate.path))
        .collect();
    sessions.sort_by_key(|session| std::cmp::Reverse(session.modified_ms));

    match args.output {
        Output::Json => println!("{}", serde_json::to_string(&sessions)?),
        Output::Ndjson => {
            for session in &sessions {
                println!("{}", serde_json::to_string(session)?);
            }
        }
        Output::Summary => {
            let summary = Summary {
                sessions: sessions.len(),
                candidates: candidates.len(),
                cache_hits,
                parsed: parsed_count,
                invalid,
                elapsed_ms: started.elapsed().as_millis(),
                inventory_ms,
                cache_load_ms,
                parse_ms,
                cache_write_ms,
                search_text_bytes: sessions
                    .iter()
                    .map(|info| info.all_messages_text.len())
                    .sum(),
            };
            println!("{}", serde_json::to_string_pretty(&summary)?);
        }
    }

    Ok(())
}

fn parse_args() -> Result<Args> {
    let mut sessions_dir = None;
    let mut cache_path = None;
    let mut output = Output::Summary;
    let mut values = env::args().skip(1);

    while let Some(argument) = values.next() {
        match argument.as_str() {
            "--sessions-dir" => sessions_dir = values.next().map(PathBuf::from),
            "--cache" => cache_path = values.next().map(PathBuf::from),
            "--no-cache" => cache_path = None,
            "--output" => {
                output = match values.next().as_deref() {
                    Some("summary") => Output::Summary,
                    Some("json") => Output::Json,
                    Some("ndjson") => Output::Ndjson,
                    Some(value) => bail!("unsupported output format: {value}"),
                    None => bail!("--output requires a value"),
                }
            }
            "--help" | "-h" => {
                println!(
                    "Usage: pi-session-index --sessions-dir PATH [--cache PATH] [--output summary|json|ndjson]"
                );
                std::process::exit(0);
            }
            value => bail!("unknown argument: {value}"),
        }
    }

    Ok(Args {
        sessions_dir: sessions_dir.context("--sessions-dir is required")?,
        cache_path,
        output,
    })
}

fn discover_candidates(root: &Path) -> Result<Vec<Candidate>> {
    let mut paths = Vec::new();
    for entry in fs::read_dir(root).with_context(|| format!("read {}", root.display()))? {
        let path = entry?.path();
        if !path.is_dir() {
            continue;
        }
        let Ok(entries) = fs::read_dir(&path) else {
            continue;
        };
        for entry in entries.flatten() {
            let path = entry.path();
            if path.extension().and_then(|extension| extension.to_str()) == Some("jsonl") {
                paths.push(path);
            }
        }
    }

    paths
        .into_par_iter()
        .filter_map(|path| fingerprint_candidate(path).transpose())
        .collect()
}

fn fingerprint_candidate(path: PathBuf) -> Result<Option<Candidate>> {
    let metadata = match fs::metadata(&path) {
        Ok(metadata) if metadata.is_file() => metadata,
        _ => return Ok(None),
    };
    let size = metadata.len();
    let mtime_ns = metadata
        .modified()
        .ok()
        .and_then(|time| time.duration_since(UNIX_EPOCH).ok())
        .map(|duration| i64::try_from(duration.as_nanos()).unwrap_or(i64::MAX))
        .unwrap_or(0);
    let (file_id, ctime_ns) = {
        use std::os::unix::fs::MetadataExt;
        (
            format!("{}:{}", metadata.dev(), metadata.ino()),
            metadata
                .ctime()
                .saturating_mul(1_000_000_000)
                .saturating_add(metadata.ctime_nsec()),
        )
    };
    let mut file = File::open(&path)?;
    let mut prefix = vec![0; FINGERPRINT_BYTES.min(size as usize)];
    file.read_exact(&mut prefix)?;
    let tail_start = size.saturating_sub(FINGERPRINT_BYTES as u64);
    file.seek(SeekFrom::Start(tail_start))?;
    let mut tail = Vec::with_capacity((size - tail_start) as usize);
    file.read_to_end(&mut tail)?;

    Ok(Some(Candidate {
        path,
        size,
        mtime_ns,
        file_id,
        ctime_ns,
        prefix_hash: blake3::hash(&prefix).to_hex().to_string(),
        tail_hash: blake3::hash(&tail).to_hex().to_string(),
    }))
}

fn candidate_matches(left: &Candidate, right: &Candidate) -> bool {
    left.size == right.size
        && left.mtime_ns == right.mtime_ns
        && left.file_id == right.file_id
        && left.ctime_ns == right.ctime_ns
        && left.prefix_hash == right.prefix_hash
        && left.tail_hash == right.tail_hash
}

fn parse_session(candidate: &Candidate) -> Result<Option<SessionInfo>> {
    let file = File::open(&candidate.path)?;
    let mut reader = BufReader::with_capacity(1024 * 1024, file);
    let mut line_bytes = Vec::new();
    let mut header: Option<Entry> = None;
    let mut name = None;
    let mut message_count = 0_u64;
    let mut last_activity_ms = None;
    let mut first_message = None;
    let mut messages = Vec::new();

    loop {
        line_bytes.clear();
        if reader.read_until(b'\n', &mut line_bytes)? == 0 {
            break;
        }
        while matches!(line_bytes.last(), Some(b'\n' | b'\r')) {
            line_bytes.pop();
        }
        let line = String::from_utf8_lossy(&line_bytes);
        if line.trim().is_empty() {
            continue;
        }
        let entry = match serde_json::from_str::<Entry>(&line) {
            Ok(entry) => entry,
            Err(_) => {
                if header.is_some()
                    && serde_json::from_str::<EntryKind>(&line)
                        .is_ok_and(|entry| entry.kind.as_deref() == Some("message"))
                {
                    message_count += 1;
                }
                continue;
            }
        };
        if header.is_none() {
            if entry.kind.as_deref() != Some("session") || entry.id.is_none() {
                return Ok(None);
            }
            header = Some(entry);
            continue;
        }
        if entry.kind.as_deref() == Some("session_info") {
            name = entry.name.and_then(|value| {
                let trimmed = value.trim();
                (!trimmed.is_empty()).then(|| trimmed.to_owned())
            });
        }
        if entry.kind.as_deref() != Some("message") {
            continue;
        }
        message_count += 1;
        let Some(message) = entry.message else {
            continue;
        };
        if matches!(message.role.as_deref(), Some("user" | "assistant")) {
            let activity = numeric_value_to_millis(message.timestamp.as_ref())
                .or_else(|| value_to_millis(entry.timestamp.as_ref()));
            if let Some(activity) = activity {
                last_activity_ms = Some(last_activity_ms.unwrap_or(0).max(activity));
            }
            let text = extract_text(message.content.as_ref());
            if !text.is_empty() {
                if first_message.is_none() && message.role.as_deref() == Some("user") {
                    first_message = Some(text.clone());
                }
                messages.push(text);
            }
        }
    }

    let Some(header) = header else {
        return Ok(None);
    };
    let created_ms = value_to_millis(header.timestamp.as_ref()).unwrap_or(0);
    let filesystem_mtime_ms = candidate.mtime_ns / 1_000_000;

    Ok(Some(SessionInfo {
        path: candidate.path.to_string_lossy().into_owned(),
        id: header.id.unwrap_or_default(),
        cwd: header.cwd.unwrap_or_default(),
        name,
        parent_session_path: header.parent_session,
        created_ms,
        modified_ms: last_activity_ms.unwrap_or(if created_ms != 0 {
            created_ms
        } else {
            filesystem_mtime_ms
        }),
        message_count,
        first_message: first_message.unwrap_or_else(|| "(no messages)".to_owned()),
        all_messages_text: messages.join(" "),
    }))
}

fn extract_text(content: Option<&Content>) -> String {
    match content {
        Some(Content::Text(text)) => text.clone(),
        Some(Content::Blocks(blocks)) => blocks
            .iter()
            .filter(|block| block.kind.as_deref() == Some("text"))
            .filter_map(|block| block.text.as_deref())
            .collect::<Vec<_>>()
            .join(" "),
        Some(Content::Other(value)) => {
            let _ = value;
            String::new()
        }
        None => String::new(),
    }
}

fn numeric_value_to_millis(value: Option<&serde_json::Value>) -> Option<i64> {
    match value? {
        serde_json::Value::Number(number) => number.as_i64(),
        _ => None,
    }
}

fn value_to_millis(value: Option<&serde_json::Value>) -> Option<i64> {
    match value? {
        serde_json::Value::Number(number) => number.as_i64(),
        serde_json::Value::String(value) => DateTime::parse_from_rfc3339(value)
            .ok()
            .map(|date| date.timestamp_millis()),
        _ => None,
    }
}

fn open_cache(path: &Path) -> Result<Connection> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    if !path.exists() {
        let mut options = OpenOptions::new();
        options.create_new(true).write(true);
        #[cfg(unix)]
        {
            use std::os::unix::fs::OpenOptionsExt;
            options.mode(0o600);
        }
        if let Err(error) = options.open(path)
            && error.kind() != std::io::ErrorKind::AlreadyExists
        {
            return Err(error.into());
        }
    }
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        fs::set_permissions(path, fs::Permissions::from_mode(0o600))?;
    }
    let connection = Connection::open(path)?;
    connection.busy_timeout(std::time::Duration::from_secs(5))?;
    connection.pragma_update(None, "journal_mode", "DELETE")?;
    connection.execute(
        "CREATE TABLE IF NOT EXISTS metadata (key TEXT PRIMARY KEY, value INTEGER NOT NULL)",
        [],
    )?;
    let version: Option<i64> = connection
        .query_row(
            "SELECT value FROM metadata WHERE key = 'schema_version'",
            [],
            |row| row.get(0),
        )
        .ok();
    if version != Some(SCHEMA_VERSION) {
        connection.execute("DROP TABLE IF EXISTS sessions", [])?;
    }
    connection.execute_batch(
        "CREATE TABLE IF NOT EXISTS sessions (
           path TEXT PRIMARY KEY,
           size INTEGER NOT NULL,
           mtime_ns INTEGER NOT NULL,
           file_id TEXT NOT NULL,
           ctime_ns INTEGER NOT NULL,
           prefix_hash TEXT NOT NULL,
           tail_hash TEXT NOT NULL,
           info_json TEXT NOT NULL
         );",
    )?;
    if version != Some(SCHEMA_VERSION) {
        connection.execute(
            "INSERT OR REPLACE INTO metadata(key, value) VALUES ('schema_version', ?1)",
            [SCHEMA_VERSION],
        )?;
    }
    Ok(connection)
}

fn load_cache(connection: &Connection) -> Result<HashMap<String, (Candidate, SessionInfo)>> {
    let mut statement = connection
        .prepare(
            "SELECT path, size, mtime_ns, file_id, ctime_ns, prefix_hash, tail_hash, info_json FROM sessions",
        )?;
    let rows = statement.query_map([], |row| {
        let path: String = row.get(0)?;
        let candidate = Candidate {
            path: PathBuf::from(&path),
            size: row.get(1)?,
            mtime_ns: row.get(2)?,
            file_id: row.get(3)?,
            ctime_ns: row.get(4)?,
            prefix_hash: row.get(5)?,
            tail_hash: row.get(6)?,
        };
        let info_json: String = row.get(7)?;
        Ok((path, candidate, info_json))
    })?;
    let mut cached = HashMap::new();
    for row in rows {
        let (path, candidate, info_json) = row?;
        if let Ok(info) = serde_json::from_str(&info_json) {
            cached.insert(path, (candidate, info));
        }
    }
    Ok(cached)
}

fn write_cache(
    connection: &mut Connection,
    candidates: &[Candidate],
    parsed: &[(Candidate, Option<SessionInfo>)],
) -> Result<()> {
    let present: HashSet<String> = candidates
        .iter()
        .map(|candidate| candidate.path.to_string_lossy().into_owned())
        .collect();
    let transaction = connection.transaction()?;
    {
        let mut statement = transaction.prepare(
            "INSERT INTO sessions
             (path, size, mtime_ns, file_id, ctime_ns, prefix_hash, tail_hash, info_json)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)
             ON CONFLICT(path) DO UPDATE SET
               size = excluded.size,
               mtime_ns = excluded.mtime_ns,
               file_id = excluded.file_id,
               ctime_ns = excluded.ctime_ns,
               prefix_hash = excluded.prefix_hash,
               tail_hash = excluded.tail_hash,
               info_json = excluded.info_json
             WHERE excluded.mtime_ns > sessions.mtime_ns
                OR (excluded.mtime_ns = sessions.mtime_ns AND excluded.ctime_ns >= sessions.ctime_ns)",
        )?;
        for (candidate, info) in parsed {
            let Some(info) = info else {
                continue;
            };
            statement.execute(params![
                candidate.path.to_string_lossy(),
                candidate.size,
                candidate.mtime_ns,
                candidate.file_id,
                candidate.ctime_ns,
                candidate.prefix_hash,
                candidate.tail_hash,
                serde_json::to_string(info)?,
            ])?;
        }
    }
    {
        let mut statement = transaction.prepare("SELECT path FROM sessions")?;
        let paths: Vec<String> = statement
            .query_map([], |row| row.get(0))?
            .collect::<rusqlite::Result<_>>()?;
        drop(statement);
        for path in paths {
            if !present.contains(&path) && !Path::new(&path).exists() {
                transaction.execute("DELETE FROM sessions WHERE path = ?1", [path])?;
            }
        }
    }
    transaction.commit()?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;
    use std::time::SystemTime;

    fn temporary_directory(name: &str) -> PathBuf {
        let nonce = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let path = env::temp_dir().join(format!(
            "pi-session-index-{name}-{}-{nonce}",
            std::process::id()
        ));
        fs::create_dir_all(&path).unwrap();
        path
    }

    #[test]
    fn parses_pi_session_metadata_and_search_text() {
        let directory = temporary_directory("parse");
        let path = directory.join("session.jsonl");
        let mut file = File::create(&path).unwrap();
        writeln!(file, r#"{{"type":"session","version":3,"id":"session-1","timestamp":"2026-01-02T03:04:05.000Z","cwd":"/tmp/project","parentSession":"/tmp/parent.jsonl"}}"#).unwrap();
        writeln!(file, r#"{{"type":"message","id":"1","timestamp":"2026-01-02T03:05:00.000Z","message":{{"role":"user","content":[{{"type":"text","text":"hello"}},{{"type":"image","data":"ignored"}}]}}}}"#).unwrap();
        writeln!(file, r#"{{"type":"message","id":"2","timestamp":"2026-01-02T03:06:00.000Z","message":{{"role":"assistant","content":"world"}}}}"#).unwrap();
        writeln!(
            file,
            r#"{{"type":"session_info","id":"3","name":" Named session "}}"#
        )
        .unwrap();
        drop(file);

        let candidate = fingerprint_candidate(path.clone()).unwrap().unwrap();
        let info = parse_session(&candidate).unwrap().unwrap();

        assert_eq!(info.path, path.to_string_lossy());
        assert_eq!(info.id, "session-1");
        assert_eq!(info.cwd, "/tmp/project");
        assert_eq!(info.name.as_deref(), Some("Named session"));
        assert_eq!(
            info.parent_session_path.as_deref(),
            Some("/tmp/parent.jsonl")
        );
        assert_eq!(info.message_count, 2);
        assert_eq!(info.first_message, "hello");
        assert_eq!(info.all_messages_text, "hello world");
        assert_eq!(info.modified_ms, 1_767_323_160_000);

        fs::remove_dir_all(directory).unwrap();
    }

    #[test]
    fn counts_malformed_message_payload_like_pi() {
        let directory = temporary_directory("malformed");
        let path = directory.join("session.jsonl");
        fs::write(
            &path,
            concat!(
                "{\"type\":\"session\",\"id\":\"session-1\",\"timestamp\":\"2026-01-01T00:00:00Z\",\"cwd\":\"/tmp\"}\n",
                "{\"type\":\"message\",\"message\":{\"role\":42,\"content\":[]}}\n"
            ),
        )
        .unwrap();

        let candidate = fingerprint_candidate(path).unwrap().unwrap();
        let info = parse_session(&candidate).unwrap().unwrap();
        assert_eq!(info.message_count, 1);
        assert_eq!(info.all_messages_text, "");

        fs::remove_dir_all(directory).unwrap();
    }

    #[test]
    fn fingerprints_detect_same_size_replacement() {
        let directory = temporary_directory("fingerprint");
        let path = directory.join("session.jsonl");
        fs::write(&path, "abcdefgh").unwrap();
        let before = fingerprint_candidate(path.clone()).unwrap().unwrap();
        fs::write(&path, "abcdEfgh").unwrap();
        let after = fingerprint_candidate(path).unwrap().unwrap();

        assert_eq!(before.size, after.size);
        assert!(!candidate_matches(&before, &after));

        fs::remove_dir_all(directory).unwrap();
    }

    #[test]
    fn cache_reuses_unchanged_sessions_and_prunes_deleted_paths() {
        let directory = temporary_directory("cache");
        let session_path = directory.join("session.jsonl");
        fs::write(
            &session_path,
            "{\"type\":\"session\",\"id\":\"session-1\",\"timestamp\":\"2026-01-01T00:00:00Z\",\"cwd\":\"/tmp\"}\n",
        )
        .unwrap();
        let candidate = fingerprint_candidate(session_path.clone())
            .unwrap()
            .unwrap();
        let info = parse_session(&candidate).unwrap();
        let cache_path = directory.join("index.sqlite3");
        let mut connection = open_cache(&cache_path).unwrap();

        write_cache(
            &mut connection,
            std::slice::from_ref(&candidate),
            &[(candidate.clone(), info)],
        )
        .unwrap();
        let cached = load_cache(&connection).unwrap();
        let (cached_candidate, cached_info) = cached.get(session_path.to_str().unwrap()).unwrap();
        assert!(candidate_matches(&candidate, cached_candidate));
        assert_eq!(cached_info.id, "session-1");

        fs::remove_file(&session_path).unwrap();
        write_cache(&mut connection, &[], &[]).unwrap();
        assert!(load_cache(&connection).unwrap().is_empty());

        drop(connection);
        fs::remove_dir_all(directory).unwrap();
    }

    #[test]
    fn replaces_invalid_utf8_like_node_stream_decoding() {
        let directory = temporary_directory("invalid-utf8");
        let path = directory.join("session.jsonl");
        let mut bytes =
            br#"{"type":"session","id":"session-1","timestamp":"2026-01-01T00:00:00Z","cwd":"/tmp"}
{"type":"message","timestamp":"2026-01-01T00:01:00Z","message":{"role":"user","content":"he"#
                .to_vec();
        bytes.push(0xff);
        bytes.extend_from_slice(b"llo\"}}\n");
        fs::write(&path, bytes).unwrap();

        let candidate = fingerprint_candidate(path).unwrap().unwrap();
        let info = parse_session(&candidate).unwrap().unwrap();
        assert_eq!(info.message_count, 1);
        assert_eq!(info.first_message, "he�llo");

        fs::remove_dir_all(directory).unwrap();
    }

    #[test]
    fn ignores_non_numeric_inner_message_timestamp() {
        let directory = temporary_directory("inner-timestamp");
        let path = directory.join("session.jsonl");
        fs::write(
            &path,
            concat!(
                "{\"type\":\"session\",\"id\":\"session-1\",\"timestamp\":\"2026-01-01T00:00:00Z\",\"cwd\":\"/tmp\"}\n",
                "{\"type\":\"message\",\"timestamp\":\"2026-01-01T00:01:00Z\",\"message\":{\"role\":\"user\",\"content\":\"hello\",\"timestamp\":\"2027-01-01T00:00:00Z\"}}\n",
            ),
        )
        .unwrap();

        let candidate = fingerprint_candidate(path).unwrap().unwrap();
        let info = parse_session(&candidate).unwrap().unwrap();
        assert_eq!(info.modified_ms, 1_767_225_660_000);

        fs::remove_dir_all(directory).unwrap();
    }

    #[test]
    fn parse_errors_are_not_treated_as_invalid_sessions() {
        let directory = temporary_directory("parse-error");
        let path = directory.join("session.jsonl");
        fs::write(
            &path,
            "{\"type\":\"session\",\"id\":\"session-1\",\"timestamp\":\"2026-01-01T00:00:00Z\",\"cwd\":\"/tmp\"}\n",
        )
        .unwrap();
        let candidate = fingerprint_candidate(path.clone()).unwrap().unwrap();
        fs::remove_file(path).unwrap();

        assert!(parse_session(&candidate).is_err());

        fs::remove_dir_all(directory).unwrap();
    }

    #[test]
    fn append_and_truncate_invalidate_fingerprints() {
        let directory = temporary_directory("resize");
        let path = directory.join("session.jsonl");
        fs::write(&path, "abcdefgh").unwrap();
        let original = fingerprint_candidate(path.clone()).unwrap().unwrap();

        fs::write(&path, "abcdefghijkl").unwrap();
        let appended = fingerprint_candidate(path.clone()).unwrap().unwrap();
        assert!(!candidate_matches(&original, &appended));

        fs::write(&path, "abcd").unwrap();
        let truncated = fingerprint_candidate(path).unwrap().unwrap();
        assert!(!candidate_matches(&appended, &truncated));

        fs::remove_dir_all(directory).unwrap();
    }

    #[test]
    fn stale_cache_writer_cannot_replace_newer_metadata_or_delete_live_path() {
        let directory = temporary_directory("stale-writer");
        let session_path = directory.join("session.jsonl");
        fs::write(&session_path, "newer").unwrap();
        let mut newer = fingerprint_candidate(session_path.clone())
            .unwrap()
            .unwrap();
        let mut older = newer.clone();
        newer.mtime_ns = 20;
        newer.ctime_ns = 20;
        older.mtime_ns = 10;
        older.ctime_ns = 10;
        let cache_path = directory.join("index.sqlite3");
        let mut connection = open_cache(&cache_path).unwrap();
        let newer_info = SessionInfo {
            path: session_path.to_string_lossy().into_owned(),
            id: "newer".to_owned(),
            cwd: "/tmp".to_owned(),
            name: None,
            parent_session_path: None,
            created_ms: 20,
            modified_ms: 20,
            message_count: 0,
            first_message: "(no messages)".to_owned(),
            all_messages_text: String::new(),
        };
        let older_info = SessionInfo {
            id: "older".to_owned(),
            created_ms: 10,
            modified_ms: 10,
            ..newer_info.clone()
        };

        write_cache(
            &mut connection,
            std::slice::from_ref(&newer),
            &[(newer.clone(), Some(newer_info))],
        )
        .unwrap();
        write_cache(
            &mut connection,
            std::slice::from_ref(&older),
            &[(older.clone(), Some(older_info))],
        )
        .unwrap();
        write_cache(&mut connection, &[], &[]).unwrap();

        let cached = load_cache(&connection).unwrap();
        assert_eq!(
            cached.get(session_path.to_str().unwrap()).unwrap().1.id,
            "newer"
        );

        drop(connection);
        fs::remove_dir_all(directory).unwrap();
    }

    #[test]
    fn schema_upgrade_rebuilds_the_sessions_table() {
        let directory = temporary_directory("schema-upgrade");
        let cache_path = directory.join("index.sqlite3");
        let connection = Connection::open(&cache_path).unwrap();
        connection
            .execute_batch(
                "CREATE TABLE metadata (key TEXT PRIMARY KEY, value INTEGER NOT NULL);
                 INSERT INTO metadata(key, value) VALUES ('schema_version', 2);
                 CREATE TABLE sessions (path TEXT PRIMARY KEY, size INTEGER NOT NULL);",
            )
            .unwrap();
        drop(connection);

        let connection = open_cache(&cache_path).unwrap();
        let has_file_id: bool = connection
            .prepare("PRAGMA table_info(sessions)")
            .unwrap()
            .query_map([], |row| row.get::<_, String>(1))
            .unwrap()
            .collect::<rusqlite::Result<Vec<_>>>()
            .unwrap()
            .iter()
            .any(|column| column == "file_id");
        assert!(has_file_id);

        drop(connection);
        fs::remove_dir_all(directory).unwrap();
    }

    #[test]
    fn corrupt_cache_fails_closed() {
        let directory = temporary_directory("corrupt-cache");
        let cache_path = directory.join("index.sqlite3");
        fs::write(&cache_path, "not sqlite").unwrap();

        assert!(open_cache(&cache_path).is_err());

        fs::remove_dir_all(directory).unwrap();
    }

    #[cfg(unix)]
    #[test]
    fn cache_file_is_private() {
        use std::os::unix::fs::PermissionsExt;

        let directory = temporary_directory("permissions");
        let cache_path = directory.join("index.sqlite3");
        let connection = open_cache(&cache_path).unwrap();
        drop(connection);

        assert_eq!(
            fs::metadata(&cache_path).unwrap().permissions().mode() & 0o777,
            0o600
        );

        fs::remove_dir_all(directory).unwrap();
    }
}
