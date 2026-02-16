# git-commit-browser.yazi

A Yazi plugin that enables browsing git repository history through temporary worktrees, with seamless navigation between commits and automatic cleanup.

## Features

- Browse git history with `]` (older) and `[` (newer) keys
- Navigate to any commit interactively with `g]`
- Return to HEAD with `g[`
- Automatic worktree creation and cleanup
- Status line integration showing current commit
- Support for resuming from existing temp worktrees

## Installation

### Manual

Clone this repository into your Yazi plugins directory:

```bash
git clone https://github.com/yourusername/git-commit-browser.yazi \
  ~/.config/yazi/plugins/git-commit-browser.yazi
```

### Using Nix

Add to your Yazi configuration (see Nix configuration section below).

## Configuration

Add to your `~/.config/yazi/keymap.toml`:

```toml
[[manager.prepend_keymap]]
on   = "]"
run  = "plugin git-commit-browser -- next"
desc = "Next commit (older)"

[[manager.prepend_keymap]]
on   = "["
run  = "plugin git-commit-browser -- prev"
desc = "Previous commit (newer)"

[[manager.prepend_keymap]]
on   = "g["
run  = "plugin git-commit-browser -- head"
desc = "Return to HEAD/original"

[[manager.prepend_keymap]]
on   = "g]"
run  = "plugin git-commit-browser -- select"
desc = "Select commit interactively"
```

## Usage

### Basic Workflow

1. Open Yazi in any git repository
2. Press `]` to create a worktree for the previous commit and navigate to it
3. Continue pressing `]` to go further back in history
4. Press `[` to go forward (newer commits)
5. Press `g[` to return to HEAD/original directory
6. Press `q` to quit Yazi (shell will cd to current directory)

### Interactive Selection

Press `g]` to open an interactive fzf picker showing all commits with their messages.

### Status Line

The plugin publishes commit information via DDS. To display it in your status line, add to your `init.lua`:

```lua
ps.sub("git-commit-browser:commit", function(info)
  _G.git_commit_info = info
end)

Status:children_add(function(self)
  local info = _G.git_commit_info
  if info and info.is_temp then
    local msg = info.message:sub(1, 30)
    if #info.message > 30 then msg = msg .. "..." end
    return ui.Line({
      ui.Span(" [git: "):fg("#7aa2f7"),
      ui.Span(info.hash):fg("#e0af68"),
      ui.Span(' "' .. msg .. '"]'):fg("#7aa2f7"),
    })
  end
  return ui.Line({})
end, 1000, Status.LEFT)
```

## How It Works

The plugin creates temporary git worktrees under `/tmp/yazi-git-browser-<hash>/` for each commit you visit. This allows you to:

- View files as they existed at any point in history
- Make changes and create branches from old commits
- Have multiple commits accessible simultaneously

Worktrees are automatically cleaned up when you return to HEAD or quit Yazi.

## Requirements

- Yazi >= 0.2.0
- Git
- fzf (for interactive commit selection)

## License

MIT
