use std::path::PathBuf;
use std::process::ExitCode;
use std::time::Duration;

use clap::{ArgAction, Parser, Subcommand};

use hyprlayoutctl::app::{App, ApplyOptions};
use hyprlayoutctl::config::{load_resolved, resolve_layout};
use hyprlayoutctl::error::Result;
use hyprlayoutctl::hypr::{HyprRuntime, Runtime};
use hyprlayoutctl::watch::run_debounced;

#[derive(Debug, Parser)]
#[command(author, version, about)]
struct Cli {
    #[arg(long)]
    config: Option<PathBuf>,
    #[arg(long = "layout-dir", action = ArgAction::Append)]
    layout_dirs: Vec<PathBuf>,
    #[arg(long)]
    dry_run: bool,
    #[arg(long, short)]
    verbose: bool,
    #[command(subcommand)]
    command: Commands,
}

#[derive(Debug, Subcommand)]
enum Commands {
    Apply { layout: String },
    Watch { layout: String },
    List,
    Validate { layout: Option<String> },
}

fn main() -> ExitCode {
    let cli = Cli::parse();
    match run(cli) {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("error: {error}");
            ExitCode::FAILURE
        }
    }
}

fn run(cli: Cli) -> Result<()> {
    let resolved = load_resolved(cli.config, &cli.layout_dirs)?;

    let app = App {
        runtime: HyprRuntime,
        options: ApplyOptions {
            dry_run: cli.dry_run,
            verbose: cli.verbose,
        },
    };

    match cli.command {
        Commands::Apply { layout } => app.apply_named_layout(&resolved, &layout),
        Commands::List => {
            app.list_layouts(&resolved);
            Ok(())
        }
        Commands::Validate { layout } => app.validate_layouts(&resolved, layout.as_deref()),
        Commands::Watch { layout } => watch_mode(&app, &resolved, &layout),
    }
}

fn watch_mode<R: Runtime>(
    app: &App<R>,
    resolved: &hyprlayoutctl::config::ResolvedConfig,
    layout: &str,
) -> Result<()> {
    let selected = resolve_layout(layout, resolved)?;

    app.apply_discovery(resolved, &selected)?;
    let events = app.runtime.subscribe_events()?;
    run_debounced(&events, Duration::from_millis(200), || {
        app.apply_discovery(resolved, &selected)
            .map_err(|error| error.to_string())
    })
    .map_err(|detail| hyprlayoutctl::error::Error::Internal { detail })
}
