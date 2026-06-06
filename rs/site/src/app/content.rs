use std::path::Path;
use std::process::Command;

pub const SITE_CONTENT_DIR: &str = "/var/lib/rrv-sh/content";
const SITE_CONTENT_PARENT: &str = "/var/lib/rrv-sh";
const SITE_CONTENT_REPO: &str = "https://github.com/rrvsh/site-content.git";

pub fn sync() -> Result<(), String> {
    let content_dir = Path::new(SITE_CONTENT_DIR);
    let checkout_exists = content_dir.join(".git").is_dir();

    if !checkout_exists {
        println!("site content: cloning {SITE_CONTENT_REPO} into {SITE_CONTENT_DIR}");
        std::fs::create_dir_all(SITE_CONTENT_PARENT)
            .map_err(|err| format!("failed to create {SITE_CONTENT_PARENT}: {err}"))?;
        run(Command::new("git")
            .arg("clone")
            .arg(SITE_CONTENT_REPO)
            .arg(SITE_CONTENT_DIR))
        .map_err(|err| format!("failed to clone site content: {err}"))?;
        run_lfs_pull().map_err(|err| format!("failed to fetch site content LFS assets: {err}"))?;
        println!("site content: ready at {SITE_CONTENT_DIR}");
        return Ok(());
    }

    println!("site content: updating {SITE_CONTENT_DIR}");
    if let Err(err) = run(Command::new("git")
        .arg("-C")
        .arg(SITE_CONTENT_DIR)
        .arg("pull")
        .arg("--ff-only"))
    {
        eprintln!("warning: failed to update site content, using existing checkout: {err}");
    }

    if let Err(err) = run_lfs_pull() {
        eprintln!(
            "warning: failed to update site content LFS assets, using existing checkout: {err}"
        );
    }

    println!("site content: ready at {SITE_CONTENT_DIR}");
    Ok(())
}

fn run_lfs_pull() -> Result<(), String> {
    run(Command::new("git")
        .arg("-C")
        .arg(SITE_CONTENT_DIR)
        .arg("lfs")
        .arg("install")
        .arg("--local"))?;
    run(Command::new("git")
        .arg("-C")
        .arg(SITE_CONTENT_DIR)
        .arg("lfs")
        .arg("pull"))
}

fn run(command: &mut Command) -> Result<(), String> {
    let output = command
        .output()
        .map_err(|err| format!("failed to execute command: {err}"))?;

    if output.status.success() {
        return Ok(());
    }

    let stderr = String::from_utf8_lossy(&output.stderr);
    let stdout = String::from_utf8_lossy(&output.stdout);
    Err(format!(
        "command exited with status {}\nstdout:\n{}\nstderr:\n{}",
        output.status, stdout, stderr
    ))
}
