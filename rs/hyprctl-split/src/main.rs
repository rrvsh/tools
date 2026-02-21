use std::cmp::Ordering;
use std::env;
use std::process::Command;

use serde_json::Value;

#[derive(Debug, Clone)]
struct WindowInfo {
    address: String,
    title: String,
    class_name: String,
    x: i64,
    y: i64,
    width: i64,
    height: i64,
    floating: bool,
    fullscreen: i64,
}

#[derive(Debug, Clone)]
struct ActiveWorkspace {
    id: i64,
    monitor: String,
    windows: i64,
}

#[derive(Debug, Clone)]
struct MonitorInfo {
    name: String,
    width_px: i64,
    height_px: i64,
    scale: f64,
    x: i64,
    y: i64,
}

#[derive(Debug, Clone)]
struct DesiredSplit {
    left_width: i64,
    right_width: i64,
    separator: i64,
}

fn main() {
    if let Err(err) = run() {
        eprintln!("error: {err}");
        std::process::exit(1);
    }
}

fn run() -> Result<(), String> {
    let dry_run = env::args().any(|arg| arg == "--dry-run");

    let active_workspace = get_active_workspace()?;
    let layout = get_option_string("general:layout")?;
    let gaps_in = get_option_custom("general:gaps_in")?;
    let gaps_out = get_option_custom("general:gaps_out")?;
    let border_size = get_option_int("general:border_size")?;
    let monitor = get_monitor(&active_workspace.monitor)?;

    let mut workspace_windows = get_windows_for_workspace(active_workspace.id)?;
    if workspace_windows.len() != 2 {
        return Err(format!(
            "expected exactly 2 mapped windows on active workspace {}, found {}",
            active_workspace.id,
            workspace_windows.len()
        ));
    }

    workspace_windows.sort_by(|a, b| {
        let by_x = a.x.cmp(&b.x);
        if by_x == Ordering::Equal {
            a.y.cmp(&b.y)
        } else {
            by_x
        }
    });

    let left = workspace_windows[0].clone();
    let right = workspace_windows[1].clone();

    if left.fullscreen != 0 || right.fullscreen != 0 {
        return Err("cannot resize while a target window is fullscreen".to_owned());
    }

    let current_separator = right.x - (left.x + left.width);
    let combined_window_width = left.width + right.width;
    if combined_window_width <= 0 {
        return Err("invalid total width for workspace windows".to_owned());
    }

    let desired = compute_desired_split(combined_window_width, current_separator)?;

    println!("hyprctl-split plan");
    println!(
        "- active workspace: {} (monitor {})",
        active_workspace.id, active_workspace.monitor
    );
    println!(
        "- active workspace reports window count: {}",
        active_workspace.windows
    );
    println!(
        "- monitor logical size (from hyprctl): {} {}x{} (physical {}x{}, scale {:.2})",
        monitor.name,
        logical_dimension(monitor.width_px, monitor.scale),
        logical_dimension(monitor.height_px, monitor.scale),
        monitor.width_px,
        monitor.height_px,
        monitor.scale,
    );
    println!("- monitor origin: {},{}", monitor.x, monitor.y);
    println!("- layout: {layout}");
    println!("- gaps_in: {gaps_in}");
    println!("- gaps_out: {gaps_out}");
    println!("- border_size: {border_size}");
    println!(
        "- left window: {} [{}] addr={} pos=({}, {}) size={}x{} floating={}",
        left.title,
        left.class_name,
        left.address,
        left.x,
        left.y,
        left.width,
        left.height,
        left.floating,
    );
    println!(
        "- right window: {} [{}] addr={} pos=({}, {}) size={}x{} floating={}",
        right.title,
        right.class_name,
        right.address,
        right.x,
        right.y,
        right.width,
        right.height,
        right.floating,
    );
    println!("- detected separator: {} px", desired.separator);
    println!(
        "- target widths: left={} right={} (ratio {:.3}:{:.3})",
        desired.left_width,
        desired.right_width,
        desired.left_width as f64 / (desired.left_width + desired.right_width) as f64,
        desired.right_width as f64 / (desired.left_width + desired.right_width) as f64,
    );

    if dry_run {
        println!("- mode: dry-run (no changes applied)");
        return Ok(());
    }

    apply_resize(&left, desired.left_width)?;
    verify_result(active_workspace.id, desired.left_width, desired.right_width)?;

    println!("- status: applied");
    Ok(())
}

fn verify_result(workspace_id: i64, expected_left: i64, expected_right: i64) -> Result<(), String> {
    let mut windows = get_windows_for_workspace(workspace_id)?;
    windows.sort_by(|a, b| {
        let by_x = a.x.cmp(&b.x);
        if by_x == Ordering::Equal {
            a.y.cmp(&b.y)
        } else {
            by_x
        }
    });

    if windows.len() != 2 {
        return Err(format!(
            "post-apply verification failed: expected 2 windows, found {}",
            windows.len()
        ));
    }

    let left = &windows[0];
    let right = &windows[1];
    let left_ok = approx_equal(left.width, expected_left, 2);
    let right_ok = approx_equal(right.width, expected_right, 2);

    println!(
        "- verify: left={} right={} (expected {} / {})",
        left.width, right.width, expected_left, expected_right
    );

    if left_ok && right_ok {
        return Ok(());
    }

    Err(
        "post-apply verification failed: window widths differ from target beyond tolerance"
            .to_owned(),
    )
}

fn approx_equal(actual: i64, expected: i64, tolerance: i64) -> bool {
    (actual - expected).abs() <= tolerance
}

fn apply_resize(left: &WindowInfo, target_width: i64) -> Result<(), String> {
    let addr = format!("{},address:{}", left.height, left.address);
    let width = target_width.to_string();
    run_hyprctl(&["dispatch", "resizewindowpixel", "exact", &width, &addr])?;
    Ok(())
}

fn compute_desired_split(combined_width: i64, separator: i64) -> Result<DesiredSplit, String> {
    if combined_width < 3 {
        return Err("combined width too small for 1/3:2/3 split".to_owned());
    }

    let left_width = ((combined_width as f64) / 3.0).round() as i64;
    let right_width = combined_width - left_width;
    if left_width <= 0 || right_width <= 0 {
        return Err("computed invalid split widths".to_owned());
    }

    Ok(DesiredSplit {
        left_width,
        right_width,
        separator,
    })
}

fn get_active_workspace() -> Result<ActiveWorkspace, String> {
    let value = run_hyprctl_json(&["activeworkspace"])?;
    Ok(ActiveWorkspace {
        id: get_i64(&value, "id")?,
        monitor: get_string(&value, "monitor")?,
        windows: get_i64(&value, "windows")?,
    })
}

fn get_monitor(name: &str) -> Result<MonitorInfo, String> {
    let value = run_hyprctl_json(&["monitors"])?;
    let monitors = value
        .as_array()
        .ok_or_else(|| "hyprctl monitors json is not an array".to_owned())?;

    for monitor in monitors {
        if monitor.get("name").and_then(Value::as_str) == Some(name) {
            return Ok(MonitorInfo {
                name: get_string(monitor, "name")?,
                width_px: get_i64(monitor, "width")?,
                height_px: get_i64(monitor, "height")?,
                scale: get_f64(monitor, "scale")?,
                x: get_i64(monitor, "x")?,
                y: get_i64(monitor, "y")?,
            });
        }
    }

    Err(format!(
        "active monitor {name} not found in hyprctl monitors"
    ))
}

fn get_windows_for_workspace(workspace_id: i64) -> Result<Vec<WindowInfo>, String> {
    let value = run_hyprctl_json(&["clients"])?;
    let clients = value
        .as_array()
        .ok_or_else(|| "hyprctl clients json is not an array".to_owned())?;

    let mut windows = Vec::new();
    for client in clients {
        let ws = client
            .get("workspace")
            .and_then(Value::as_object)
            .ok_or_else(|| "client has no workspace object".to_owned())?;
        let ws_id = ws
            .get("id")
            .and_then(Value::as_i64)
            .ok_or_else(|| "workspace has no numeric id".to_owned())?;
        if ws_id != workspace_id {
            continue;
        }

        let mapped = get_bool(client, "mapped")?;
        let hidden = get_bool(client, "hidden")?;
        if !mapped || hidden {
            continue;
        }

        let at = get_pair(client, "at")?;
        let size = get_pair(client, "size")?;

        windows.push(WindowInfo {
            address: get_string(client, "address")?,
            title: get_string(client, "title")?,
            class_name: get_string(client, "class")?,
            x: at.0,
            y: at.1,
            width: size.0,
            height: size.1,
            floating: get_bool(client, "floating")?,
            fullscreen: get_i64(client, "fullscreen")?,
        });
    }

    Ok(windows)
}

fn get_option_string(option: &str) -> Result<String, String> {
    let value = run_hyprctl_json(&["getoption", option])?;
    get_string(&value, "str")
}

fn get_option_custom(option: &str) -> Result<String, String> {
    let value = run_hyprctl_json(&["getoption", option])?;
    get_string(&value, "custom")
}

fn get_option_int(option: &str) -> Result<i64, String> {
    let value = run_hyprctl_json(&["getoption", option])?;
    get_i64(&value, "int")
}

fn run_hyprctl_json(args: &[&str]) -> Result<Value, String> {
    let mut full_args = Vec::with_capacity(args.len() + 1);
    full_args.push("-j");
    full_args.extend(args);

    let output = run_hyprctl(&full_args)?;
    serde_json::from_str(&output).map_err(|err| format!("failed to parse hyprctl json: {err}"))
}

fn run_hyprctl(args: &[&str]) -> Result<String, String> {
    let output = Command::new("hyprctl")
        .args(args)
        .output()
        .map_err(|err| format!("failed to execute hyprctl {:?}: {err}", args))?;

    if output.status.success() {
        return String::from_utf8(output.stdout)
            .map_err(|err| format!("hyprctl output was not utf8: {err}"));
    }

    let stderr =
        String::from_utf8(output.stderr).unwrap_or_else(|_| "<non-utf8 stderr>".to_owned());
    let stdout =
        String::from_utf8(output.stdout).unwrap_or_else(|_| "<non-utf8 stdout>".to_owned());
    Err(format!(
        "hyprctl {:?} failed with status {}. stdout: {} stderr: {}",
        args,
        output.status,
        stdout.trim(),
        stderr.trim()
    ))
}

fn logical_dimension(px: i64, scale: f64) -> i64 {
    if scale <= 0.0 {
        return px;
    }
    ((px as f64) / scale).round() as i64
}

fn get_pair(value: &Value, key: &str) -> Result<(i64, i64), String> {
    let arr = value
        .get(key)
        .and_then(Value::as_array)
        .ok_or_else(|| format!("missing or invalid array field `{key}`"))?;
    if arr.len() != 2 {
        return Err(format!("array field `{key}` does not have 2 elements"));
    }

    let first = arr[0]
        .as_i64()
        .ok_or_else(|| format!("array field `{key}` first element is not integer"))?;
    let second = arr[1]
        .as_i64()
        .ok_or_else(|| format!("array field `{key}` second element is not integer"))?;
    Ok((first, second))
}

fn get_string(value: &Value, key: &str) -> Result<String, String> {
    value
        .get(key)
        .and_then(Value::as_str)
        .map(ToOwned::to_owned)
        .ok_or_else(|| format!("missing or invalid string field `{key}`"))
}

fn get_i64(value: &Value, key: &str) -> Result<i64, String> {
    value
        .get(key)
        .and_then(Value::as_i64)
        .ok_or_else(|| format!("missing or invalid integer field `{key}`"))
}

fn get_f64(value: &Value, key: &str) -> Result<f64, String> {
    value
        .get(key)
        .and_then(Value::as_f64)
        .ok_or_else(|| format!("missing or invalid float field `{key}`"))
}

fn get_bool(value: &Value, key: &str) -> Result<bool, String> {
    value
        .get(key)
        .and_then(Value::as_bool)
        .ok_or_else(|| format!("missing or invalid bool field `{key}`"))
}

#[cfg(test)]
mod tests {
    use super::{approx_equal, compute_desired_split, logical_dimension};

    #[test]
    fn split_rounds_to_nearest_pixel() {
        let desired = compute_desired_split(1916, 2).expect("split should be computable");
        assert_eq!(desired.left_width, 639);
        assert_eq!(desired.right_width, 1277);
        assert_eq!(desired.separator, 2);
    }

    #[test]
    fn split_rejects_tiny_width() {
        let err = compute_desired_split(2, 0).expect_err("width 2 must fail");
        assert!(err.contains("too small"));
    }

    #[test]
    fn logical_size_obeys_scale() {
        assert_eq!(logical_dimension(3840, 2.0), 1920);
        assert_eq!(logical_dimension(2160, 2.0), 1080);
        assert_eq!(logical_dimension(1920, 1.0), 1920);
    }

    #[test]
    fn tolerance_helper() {
        assert!(approx_equal(639, 638, 2));
        assert!(approx_equal(1277, 1279, 2));
        assert!(!approx_equal(1277, 1281, 2));
    }
}
