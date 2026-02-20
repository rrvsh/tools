use crate::config::{Discovery, LayoutSource, ResolvedConfig, resolve_layout};
use crate::engine::plan_layout;
use crate::error::{Error, Result};
use crate::hypr::Runtime;

#[derive(Debug, Clone, Copy)]
pub struct ApplyOptions {
    pub dry_run: bool,
    pub verbose: bool,
}

pub struct App<R: Runtime> {
    pub runtime: R,
    pub options: ApplyOptions,
}

#[cfg(test)]
mod tests {
    use std::collections::VecDeque;
    use std::sync::mpsc::{self, Receiver};
    use std::sync::{Arc, Mutex};

    use crate::config::{Discovery, LayoutSource, ResolvedConfig};
    use crate::engine::{Client, HyprCommand, Scope};
    use crate::hypr::Runtime;
    use crate::model::{
        AppsConfig, ConfigFile, ContentKind, ContentRule, Defaults, GeneralConfig, Layout, PaneDef,
        PaneLayout, PaneLayoutKind, PxRect, RectDef, Scalar,
    };

    use super::*;

    #[derive(Clone)]
    struct FakeRuntime {
        scope: Scope,
        clients_sequence: Arc<Mutex<VecDeque<Vec<Client>>>>,
        spawned: Arc<Mutex<Vec<String>>>,
        dispatched: Arc<Mutex<Vec<Vec<HyprCommand>>>>,
    }

    impl Runtime for FakeRuntime {
        fn scope(&self) -> Result<Scope> {
            Ok(self.scope.clone())
        }

        fn clients(&self) -> Result<Vec<Client>> {
            let mut lock = self.clients_sequence.lock().unwrap();
            if lock.len() > 1 {
                return Ok(lock.pop_front().unwrap());
            }
            Ok(lock.front().cloned().unwrap_or_default())
        }

        fn dispatch(&self, commands: &[HyprCommand], _: bool, _: bool) -> Result<()> {
            self.dispatched.lock().unwrap().push(commands.to_vec());
            Ok(())
        }

        fn spawn(&self, command: &str, _: bool, _: bool) -> Result<()> {
            self.spawned.lock().unwrap().push(command.to_string());
            Ok(())
        }

        fn subscribe_events(&self) -> Result<Receiver<String>> {
            let (_tx, rx) = mpsc::channel();
            Ok(rx)
        }
    }

    fn make_layout() -> Layout {
        Layout {
            name: "dev".to_string(),
            id: "dev".to_string(),
            defaults: Defaults {
                gap_px: 0,
                padding_px: 0,
                tall_bias: 1.35,
            },
            panes: vec![PaneDef {
                name: "all".to_string(),
                rect: RectDef {
                    x: Scalar::Text("0%".to_string()),
                    y: Scalar::Text("0%".to_string()),
                    w: Scalar::Text("100%".to_string()),
                    h: Scalar::Text("100%".to_string()),
                },
                content: ContentRule {
                    kind: ContentKind::PickOne,
                    pick: vec!["ghostty".to_string()],
                    except_panes: vec![],
                    ensure: true,
                    ensure_min: None,
                    fallback: None,
                    match_terms: vec![],
                },
                layout: PaneLayout {
                    kind: PaneLayoutKind::Single,
                    preference: None,
                },
            }],
        }
    }

    fn make_resolved(layout: Layout) -> ResolvedConfig {
        ResolvedConfig {
            config_path: "config.toml".into(),
            config: ConfigFile {
                general: GeneralConfig {
                    layout_dirs: vec![],
                },
                apps: AppsConfig {
                    ghostty_cmd: "ghostty --new-window".to_string(),
                    camera_classes: vec![],
                },
                layouts: std::collections::BTreeMap::new(),
            },
            layout_dirs: vec![],
            discovered: vec![Discovery {
                key: "dev".to_string(),
                layout,
                source: LayoutSource::Inline,
                file_stem: None,
            }],
        }
    }

    #[test]
    fn apply_refreshes_clients_after_spawn() {
        let scope = Scope {
            monitor_id: 1,
            workspace_id: 9,
            monitor_rect: PxRect {
                x: 0,
                y: 0,
                w: 1000,
                h: 700,
            },
        };

        let runtime = FakeRuntime {
            scope,
            clients_sequence: Arc::new(Mutex::new(VecDeque::from([
                vec![],
                vec![Client {
                    address: "0x1".to_string(),
                    class: "ghostty".to_string(),
                    title: "shell".to_string(),
                    monitor_id: 1,
                    workspace_id: 9,
                    floating: false,
                    x: 10,
                    y: 10,
                    w: 10,
                    h: 10,
                }],
            ]))),
            spawned: Arc::new(Mutex::new(Vec::new())),
            dispatched: Arc::new(Mutex::new(Vec::new())),
        };

        let app = App {
            runtime: runtime.clone(),
            options: ApplyOptions {
                dry_run: false,
                verbose: false,
            },
        };
        let resolved = make_resolved(make_layout());

        app.apply_named_layout(&resolved, "dev").unwrap();

        assert_eq!(
            runtime.spawned.lock().unwrap().as_slice(),
            &["ghostty --new-window"]
        );
        assert_eq!(runtime.dispatched.lock().unwrap().len(), 1);
        assert!(!runtime.dispatched.lock().unwrap()[0].is_empty());
    }
}

#[allow(clippy::items_after_test_module)]
impl<R: Runtime> App<R> {
    /// Applies a layout resolved by name or file path query.
    ///
    /// # Errors
    /// Returns an error when layout resolution fails or Hyprland operations fail.
    pub fn apply_named_layout(&self, config: &ResolvedConfig, query: &str) -> Result<()> {
        let selected = resolve_layout(query, config)?;
        self.apply_discovery(config, &selected)
    }

    /// Applies a previously discovered layout to the active Hyprland scope.
    ///
    /// # Errors
    /// Returns an error when querying scope/clients, spawning windows, or dispatching window
    /// commands fails.
    pub fn apply_discovery(&self, config: &ResolvedConfig, discovery: &Discovery) -> Result<()> {
        if self.options.verbose {
            let source = match &discovery.source {
                LayoutSource::Inline => "inline".to_string(),
                LayoutSource::File(path) => path.display().to_string(),
            };
            println!("applying layout {} from {source}", discovery.layout.name);
        }

        let scope = self.runtime.scope()?;
        let clients = self.runtime.clients()?;
        let mut plan = plan_layout(&discovery.layout, &config.config.apps, &clients, &scope);

        for spawn_command in &plan.spawn_commands {
            self.runtime
                .spawn(spawn_command, self.options.dry_run, self.options.verbose)?;
        }

        if !plan.spawn_commands.is_empty() && !self.options.dry_run {
            let refreshed_clients = self.runtime.clients()?;
            plan = plan_layout(
                &discovery.layout,
                &config.config.apps,
                &refreshed_clients,
                &scope,
            );
        }

        self.runtime
            .dispatch(&plan.commands, self.options.dry_run, self.options.verbose)
    }

    pub fn list_layouts(&self, config: &ResolvedConfig) {
        for item in &config.discovered {
            let source = match &item.source {
                LayoutSource::Inline => "inline".to_string(),
                LayoutSource::File(path) => format!("file:{}", path.display()),
            };
            println!("{}\t{}\t{}", item.layout.name, item.layout.id, source);
        }
    }

    /// Validates one or all discovered layouts.
    ///
    /// # Errors
    /// Returns an error when the target layout cannot be resolved or any layout is invalid.
    pub fn validate_layouts(
        &self,
        config: &ResolvedConfig,
        maybe_name: Option<&str>,
    ) -> Result<()> {
        if let Some(name) = maybe_name {
            let item = resolve_layout(name, config)?;
            item.layout.validate()?;
            println!("ok: {}", item.layout.name);
            return Ok(());
        }

        if config.discovered.is_empty() {
            return Err(Error::Internal {
                detail: "no layouts found".to_string(),
            });
        }

        for item in &config.discovered {
            item.layout.validate()?;
            println!("ok: {}", item.layout.name);
        }
        Ok(())
    }
}
