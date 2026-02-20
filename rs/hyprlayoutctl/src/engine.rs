use std::collections::{HashMap, HashSet};

use crate::model::{
    AppsConfig, ContentKind, Defaults, GridPreference, Layout, PaneDef, PaneLayoutKind, PxRect,
};

#[derive(Debug, Clone)]
pub struct Scope {
    pub monitor_id: i32,
    pub workspace_id: i32,
    pub monitor_rect: PxRect,
}

#[derive(Debug, Clone)]
pub struct Client {
    pub address: String,
    pub class: String,
    pub title: String,
    pub monitor_id: i32,
    pub workspace_id: i32,
    pub floating: bool,
    pub x: i32,
    pub y: i32,
    pub w: i32,
    pub h: i32,
}

#[derive(Debug, Clone)]
pub enum HyprCommand {
    SetFloating { address: String },
    Move { address: String, x: i32, y: i32 },
    Resize { address: String, w: i32, h: i32 },
}

#[derive(Debug, Clone)]
pub struct Plan {
    pub commands: Vec<HyprCommand>,
    pub spawn_commands: Vec<String>,
}

#[must_use]
pub fn plan_layout(layout: &Layout, apps: &AppsConfig, clients: &[Client], scope: &Scope) -> Plan {
    let scoped_clients = clients
        .iter()
        .filter(|client| {
            client.monitor_id == scope.monitor_id && client.workspace_id == scope.workspace_id
        })
        .cloned()
        .collect::<Vec<_>>();

    let assignments = assign_panes(layout, apps, &scoped_clients);
    let commands = place_clients(layout, &scoped_clients, &assignments, scope);

    Plan {
        commands,
        spawn_commands: assignments.spawn_commands,
    }
}

#[derive(Debug, Clone)]
struct Assignments {
    by_pane: HashMap<String, Vec<usize>>,
    spawn_commands: Vec<String>,
}

fn assign_panes(layout: &Layout, apps: &AppsConfig, clients: &[Client]) -> Assignments {
    let mut by_pane: HashMap<String, Vec<usize>> = HashMap::new();
    let mut assigned = HashSet::new();
    let mut spawn_commands = Vec::new();

    for pane in &layout.panes {
        let selected = select_for_pane(pane, apps, clients, &by_pane, &assigned);
        let selected_set = selected.iter().copied().collect::<HashSet<_>>();
        assigned.extend(selected_set);

        let desired_min = pane
            .content
            .ensure_min
            .unwrap_or_else(|| usize::from(pane.content.ensure));
        if selected.len() < desired_min {
            let missing = desired_min - selected.len();
            if let Some(command) = spawn_command_for_pane(pane, apps) {
                spawn_commands.extend(vec![command; missing]);
            }
        }
        by_pane.insert(pane.name.clone(), selected);
    }

    Assignments {
        by_pane,
        spawn_commands,
    }
}

fn select_for_pane(
    pane: &PaneDef,
    apps: &AppsConfig,
    clients: &[Client],
    by_pane: &HashMap<String, Vec<usize>>,
    assigned: &HashSet<usize>,
) -> Vec<usize> {
    match pane.content.kind {
        ContentKind::PickOne => {
            let mut result = Vec::new();
            for token in &pane.content.pick {
                if let Some((index, _)) = clients.iter().enumerate().find(|(idx, client)| {
                    !assigned.contains(idx) && client_matches_token(client, token, apps)
                }) {
                    result.push(index);
                    break;
                }
            }
            result
        }
        ContentKind::All => clients
            .iter()
            .enumerate()
            .filter_map(|(idx, _)| (!assigned.contains(&idx)).then_some(idx))
            .collect(),
        ContentKind::AllExcept => {
            let mut excluded = HashSet::new();
            for pane_name in &pane.content.except_panes {
                if let Some(entries) = by_pane.get(pane_name) {
                    excluded.extend(entries.iter().copied());
                }
            }
            clients
                .iter()
                .enumerate()
                .filter_map(|(idx, _)| {
                    (!assigned.contains(&idx) && !excluded.contains(&idx)).then_some(idx)
                })
                .collect()
        }
        ContentKind::Match => clients
            .iter()
            .enumerate()
            .filter_map(|(idx, client)| {
                (!assigned.contains(&idx)
                    && pane
                        .content
                        .match_terms
                        .iter()
                        .any(|token| client_matches_token(client, token, apps)))
                .then_some(idx)
            })
            .collect(),
    }
}

fn client_matches_token(client: &Client, token: &str, apps: &AppsConfig) -> bool {
    let token_lower = token.to_ascii_lowercase();
    let class_lower = client.class.to_ascii_lowercase();
    let title_lower = client.title.to_ascii_lowercase();

    if token_lower == "camera" {
        return apps
            .camera_classes
            .iter()
            .map(|value| value.to_ascii_lowercase())
            .any(|value| class_lower.contains(&value));
    }

    class_lower.contains(&token_lower) || title_lower.contains(&token_lower)
}

fn spawn_command_for_pane(pane: &PaneDef, apps: &AppsConfig) -> Option<String> {
    if let Some(fallback) = &pane.content.fallback {
        return spawn_token_to_command(fallback, apps);
    }

    if pane.content.kind == ContentKind::PickOne {
        pane.content
            .pick
            .iter()
            .find_map(|value| spawn_token_to_command(value, apps))
    } else {
        None
    }
}

fn spawn_token_to_command(token: &str, apps: &AppsConfig) -> Option<String> {
    if token.eq_ignore_ascii_case("ghostty") {
        Some(apps.ghostty_cmd.clone())
    } else if token.eq_ignore_ascii_case("camera") {
        None
    } else {
        Some(token.to_string())
    }
}

fn place_clients(
    layout: &Layout,
    clients: &[Client],
    assignments: &Assignments,
    scope: &Scope,
) -> Vec<HyprCommand> {
    let defaults = layout.defaults;
    let mut commands = Vec::new();

    for pane in &layout.panes {
        let Some(client_indexes) = assignments.by_pane.get(&pane.name) else {
            continue;
        };
        if client_indexes.is_empty() {
            continue;
        }
        let pane_rect = pane_rect_in_scope(pane, defaults, scope.monitor_rect);
        let target_rects = target_rects_for_pane(client_indexes.len(), pane, pane_rect, defaults);

        for (rect, client_idx) in target_rects.iter().zip(client_indexes.iter().copied()) {
            let client = &clients[client_idx];

            if !client.floating {
                commands.push(HyprCommand::SetFloating {
                    address: client.address.clone(),
                });
            }
            if client.x != rect.x || client.y != rect.y {
                commands.push(HyprCommand::Move {
                    address: client.address.clone(),
                    x: rect.x,
                    y: rect.y,
                });
            }
            if client.w != rect.w || client.h != rect.h {
                commands.push(HyprCommand::Resize {
                    address: client.address.clone(),
                    w: rect.w,
                    h: rect.h,
                });
            }
        }
    }

    commands
}

fn pane_rect_in_scope(pane: &PaneDef, defaults: Defaults, monitor_rect: PxRect) -> PxRect {
    let relative = pane
        .rect
        .to_px(monitor_rect.w, monitor_rect.h)
        .unwrap_or(PxRect {
            x: 0,
            y: 0,
            w: monitor_rect.w,
            h: monitor_rect.h,
        });

    let mut x = monitor_rect.x + relative.x + defaults.padding_px;
    let mut y = monitor_rect.y + relative.y + defaults.padding_px;
    let mut w = relative.w - (defaults.padding_px * 2);
    let mut h = relative.h - (defaults.padding_px * 2);

    if w < 1 {
        w = 1;
    }
    if h < 1 {
        h = 1;
    }
    if x < monitor_rect.x {
        x = monitor_rect.x;
    }
    if y < monitor_rect.y {
        y = monitor_rect.y;
    }
    PxRect { x, y, w, h }
}

fn target_rects_for_pane(
    count: usize,
    pane: &PaneDef,
    pane_rect: PxRect,
    defaults: Defaults,
) -> Vec<PxRect> {
    match pane.layout.kind {
        PaneLayoutKind::Single => vec![pane_rect; count],
        PaneLayoutKind::Grid => grid_rects(
            count,
            pane_rect,
            pane.layout.preference.unwrap_or(GridPreference::Square),
            defaults,
        ),
    }
}

#[allow(
    clippy::cast_possible_truncation,
    clippy::cast_precision_loss,
    clippy::cast_sign_loss
)]
fn grid_rects(
    count: usize,
    pane_rect: PxRect,
    preference: GridPreference,
    defaults: Defaults,
) -> Vec<PxRect> {
    if count == 0 {
        return Vec::new();
    }

    let count_f = count as f64;
    let tall_bias = defaults.tall_bias.max(1.0);
    let (rows, cols) = match preference {
        GridPreference::Square => {
            let cols = count_f.sqrt().ceil() as usize;
            let rows = count.div_ceil(cols);
            (rows, cols)
        }
        GridPreference::Tall => {
            let rows = (count_f * tall_bias).sqrt().ceil() as usize;
            let rows = rows.max(1);
            let cols = count.div_ceil(rows);
            (rows, cols)
        }
        GridPreference::Wide => {
            let cols = (count_f * tall_bias).sqrt().ceil() as usize;
            let cols = cols.max(1);
            let rows = count.div_ceil(cols);
            (rows, cols)
        }
    };

    let gap = defaults.gap_px.max(0);
    let cols_i32 = i32::try_from(cols).unwrap_or(1);
    let rows_i32 = i32::try_from(rows).unwrap_or(1);

    let total_gap_w = gap * (cols_i32 - 1).max(0);
    let total_gap_h = gap * (rows_i32 - 1).max(0);
    let base_w = ((pane_rect.w - total_gap_w).max(1)) / cols_i32;
    let base_h = ((pane_rect.h - total_gap_h).max(1)) / rows_i32;

    let mut rects = Vec::with_capacity(count);
    for idx in 0..count {
        let row = idx / cols;
        let col = idx % cols;

        let col_idx_i32 = i32::try_from(col).unwrap_or(0);
        let row_idx_i32 = i32::try_from(row).unwrap_or(0);

        let mut x = pane_rect.x + (col_idx_i32 * (base_w + gap));
        let mut y = pane_rect.y + (row_idx_i32 * (base_h + gap));
        let mut w = base_w;
        let mut h = base_h;

        if col + 1 == cols {
            w = (pane_rect.x + pane_rect.w - x).max(1);
        }
        if row + 1 == rows {
            h = (pane_rect.y + pane_rect.h - y).max(1);
        }

        if x < pane_rect.x {
            x = pane_rect.x;
        }
        if y < pane_rect.y {
            y = pane_rect.y;
        }

        rects.push(PxRect { x, y, w, h });
    }

    rects
}

#[cfg(test)]
mod tests {
    use crate::model::{ContentRule, PaneLayout, RectDef, Scalar};

    use super::*;

    fn test_layout() -> Layout {
        Layout {
            name: "dev".to_string(),
            id: "dev".to_string(),
            defaults: Defaults {
                gap_px: 8,
                padding_px: 8,
                tall_bias: 1.35,
            },
            panes: vec![
                PaneDef {
                    name: "left".to_string(),
                    rect: RectDef {
                        x: Scalar::Text("0%".to_string()),
                        y: Scalar::Text("0%".to_string()),
                        w: Scalar::Text("50%".to_string()),
                        h: Scalar::Text("100%".to_string()),
                    },
                    content: ContentRule {
                        kind: ContentKind::PickOne,
                        pick: vec!["camera".to_string(), "ghostty".to_string()],
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
                },
                PaneDef {
                    name: "right".to_string(),
                    rect: RectDef {
                        x: Scalar::Text("50%".to_string()),
                        y: Scalar::Text("0%".to_string()),
                        w: Scalar::Text("50%".to_string()),
                        h: Scalar::Text("100%".to_string()),
                    },
                    content: ContentRule {
                        kind: ContentKind::AllExcept,
                        pick: vec![],
                        except_panes: vec!["left".to_string()],
                        ensure: false,
                        ensure_min: Some(1),
                        fallback: Some("ghostty".to_string()),
                        match_terms: vec![],
                    },
                    layout: PaneLayout {
                        kind: PaneLayoutKind::Grid,
                        preference: Some(GridPreference::Tall),
                    },
                },
            ],
        }
    }

    #[test]
    fn plans_commands_with_minimal_churn() {
        let layout = test_layout();
        let apps = AppsConfig {
            ghostty_cmd: "ghostty".to_string(),
            camera_classes: vec!["cheese".to_string()],
        };
        let scope = Scope {
            monitor_id: 0,
            workspace_id: 1,
            monitor_rect: PxRect {
                x: 0,
                y: 0,
                w: 1200,
                h: 800,
            },
        };
        let clients = vec![
            Client {
                address: "0x1".to_string(),
                class: "cheese".to_string(),
                title: "cam".to_string(),
                monitor_id: 0,
                workspace_id: 1,
                floating: true,
                x: 8,
                y: 8,
                w: 584,
                h: 784,
            },
            Client {
                address: "0x2".to_string(),
                class: "ghostty".to_string(),
                title: "term".to_string(),
                monitor_id: 0,
                workspace_id: 1,
                floating: false,
                x: 0,
                y: 0,
                w: 100,
                h: 100,
            },
        ];

        let plan = plan_layout(&layout, &apps, &clients, &scope);
        assert!(plan.spawn_commands.is_empty());
        assert!(
            plan.commands
                .iter()
                .any(|cmd| matches!(cmd, HyprCommand::SetFloating { address } if address == "0x2"))
        );
        assert!(
            plan.commands
                .iter()
                .all(|cmd| !matches!(cmd, HyprCommand::Move { address, .. } if address == "0x1"))
        );
        assert!(
            plan.commands
                .iter()
                .all(|cmd| !matches!(cmd, HyprCommand::Resize { address, .. } if address == "0x1"))
        );
    }

    #[test]
    fn plans_spawns_for_ensured_pane() {
        let layout = test_layout();
        let scope = Scope {
            monitor_id: 0,
            workspace_id: 1,
            monitor_rect: PxRect {
                x: 0,
                y: 0,
                w: 1200,
                h: 800,
            },
        };

        let apps = AppsConfig {
            ghostty_cmd: "ghostty --new-window".to_string(),
            camera_classes: vec!["obs".to_string()],
        };
        let plan = plan_layout(&layout, &apps, &[], &scope);

        assert_eq!(
            plan.spawn_commands,
            vec!["ghostty --new-window", "ghostty --new-window"]
        );
    }

    #[test]
    fn grid_tall_pref_prefers_more_rows() {
        let defaults = Defaults {
            gap_px: 4,
            padding_px: 0,
            tall_bias: 1.35,
        };
        let rects = grid_rects(
            5,
            PxRect {
                x: 0,
                y: 0,
                w: 1000,
                h: 800,
            },
            GridPreference::Tall,
            defaults,
        );

        assert_eq!(rects.len(), 5);
        let y_values = rects.iter().map(|item| item.y).collect::<HashSet<_>>();
        let x_values = rects.iter().map(|item| item.x).collect::<HashSet<_>>();
        assert!(y_values.len() >= x_values.len());
    }
}
