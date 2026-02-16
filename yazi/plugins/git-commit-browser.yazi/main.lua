-- git-commit-browser.yazi
-- Browse git repository history through temporary worktrees

local state = {
  original_repo = nil,        -- Absolute path to original .git
  original_cwd = nil,         -- Absolute path to original working directory
  repo_hash = nil,            -- 8-char hash of original_repo path
  current_commit = nil,       -- Current commit hash
  commit_list = {},           -- Ordered list of commits for navigation
  commit_index = 1,           -- Current position in commit_list
  worktrees = {},             -- Map: commit_hash -> worktree_path
  quit_with_q = false,        -- Flag to skip cleanup
  is_temp_worktree = false,   -- Whether we started in a temp worktree
  initialized = false,        -- Whether state has been initialized
}

-- Initialize the plugin state
local function init()
  if state.initialized then return true end
  
  local cwd = ya.cwd()
  if not cwd then
    ya.notify({ title = "Git Commit Browser", content = "Failed to get current directory", timeout = 3 })
    return false
  end
  
  state.original_cwd = tostring(cwd)
  
  -- Check if we're in a temp worktree
  local temp_pattern = "/tmp/yazi%-git%-browser%-"
  if state.original_cwd:match(temp_pattern) then
    state.is_temp_worktree = true
    -- Extract repo_hash from path
    state.repo_hash = state.original_cwd:match("/tmp/yazi%-git%-browser%-([^/]+)/")
    
    -- Find original repo using git worktree list
    local output, err = Command("git")
      :args({ "worktree", "list", "--porcelain" })
      :cwd(state.original_cwd)
      :output()
    
    if err then
      ya.notify({ title = "Git Commit Browser", content = "Failed to find original repo: " .. tostring(err), timeout = 3 })
      return false
    end
    
    -- Parse worktree list to find the main worktree
    for line in output.stdout:gmatch("[^\r\n]+") do
      if line:match("^worktree ") then
        local wt_path = line:sub(10)
        -- Check if this is the main worktree (not our temp one)
        if not wt_path:match(temp_pattern) then
          state.original_repo = wt_path
          break
        end
      end
    end
  else
    -- We're in the original repo
    state.is_temp_worktree = false
    state.original_repo = state.original_cwd
    -- Compute hash of repo path
    local output, err = Command("sh")
      :args({ "-c", "echo '" .. state.original_repo .. "' | sha256sum | cut -c1-8" })
      :output()
    if err then
      -- Fallback to simple hash
      local hash = 0
      for i = 1, #state.original_repo do
        hash = (hash * 31 + state.original_repo:byte(i)) % 100000000
      end
      state.repo_hash = string.format("%08x", hash)
    else
      state.repo_hash = output.stdout:gsub("%s+", "")
    end
  end
  
  if not state.original_repo then
    ya.notify({ title = "Git Commit Browser", content = "Not in a git repository", timeout = 3 })
    return false
  end
  
  -- Load commit list
  load_commits()
  
  state.initialized = true
  return true
end

-- Load ordered list of commits
local function load_commits()
  local output, err = Command("git")
    :args({ "log", "--format=%H", "--all" })
    :cwd(state.original_repo)
    :output()
  
  if err then
    ya.notify({ title = "Git Commit Browser", content = "Failed to load commits: " .. tostring(err), timeout = 3 })
    return
  end
  
  state.commit_list = {}
  for hash in output.stdout:gmatch("%x+") do
    table.insert(state.commit_list, hash)
  end
  
  -- Set current index based on current directory
  if state.is_temp_worktree then
    -- Extract commit from path
    local commit = state.original_cwd:match("/([^/]+)$")
    for i, c in ipairs(state.commit_list) do
      if c:sub(1, 7) == commit then
        state.commit_index = i
        state.current_commit = c
        break
      end
    end
  else
    -- Get HEAD commit
    local head_output, head_err = Command("git")
      :args({ "rev-parse", "HEAD" })
      :cwd(state.original_repo)
      :output()
    
    if not head_err then
      state.current_commit = head_output.stdout:gsub("%s+", "")
      for i, c in ipairs(state.commit_list) do
        if c == state.current_commit then
          state.commit_index = i
          break
        end
      end
    end
  end
  
  -- Publish current commit info
  publish_commit_info()
end

-- Get temp base directory
local function get_temp_base()
  return "/tmp/yazi-git-browser-" .. state.repo_hash
end

-- Create worktree for a commit
local function create_worktree(commit)
  if state.worktrees[commit] then
    return state.worktrees[commit]
  end
  
  local short_hash = commit:sub(1, 7)
  local temp_base = get_temp_base()
  local wt_path = temp_base .. "/" .. short_hash
  
  -- Create temp base if needed
  Command("mkdir"):args({ "-p", temp_base }):output()
  
  -- Check if worktree already exists
  local check_cmd = Command("test"):args({ "-d", wt_path }):output()
  if check_cmd.status and check_cmd.status.code == 0 then
    state.worktrees[commit] = wt_path
    return wt_path
  end
  
  -- Create worktree
  local output, err = Command("git")
    :args({ "worktree", "add", "--detach", wt_path, commit })
    :cwd(state.original_repo)
    :output()
  
  if err then
    ya.notify({ title = "Git Commit Browser", content = "Failed to create worktree: " .. tostring(err), timeout = 3 })
    return nil
  end
  
  state.worktrees[commit] = wt_path
  return wt_path
end

-- Navigate to a specific commit by index
local function navigate_to_index(index)
  if index < 1 or index > #state.commit_list then
    return false
  end
  
  state.commit_index = index
  local commit = state.commit_list[index]
  state.current_commit = commit
  
  local wt_path = create_worktree(commit)
  if not wt_path then
    return false
  end
  
  -- Change directory
  ya.emit("cd", { target = wt_path })
  
  -- Publish commit info for status line
  publish_commit_info()
  
  return true
end

-- Navigate direction: "prev" or "next"
local function navigate(direction)
  if not init() then return end
  
  local new_index
  if direction == "next" then
    new_index = state.commit_index + 1
  elseif direction == "prev" then
    new_index = state.commit_index - 1
  else
    return
  end
  
  if new_index < 1 then
    ya.notify({ title = "Git Commit Browser", content = "Already at newest commit", timeout = 2 })
    return
  end
  
  if new_index > #state.commit_list then
    ya.notify({ title = "Git Commit Browser", content = "Already at oldest commit", timeout = 2 })
    return
  end
  
  navigate_to_index(new_index)
end

-- Go to HEAD commit
local function goto_head()
  if not init() then return end
  
  -- Check if at HEAD
  if state.commit_index == 1 then
    if state.is_temp_worktree then
      -- Return to original directory
      ya.emit("cd", { target = state.original_cwd })
      cleanup()
    else
      ya.notify({ title = "Git Commit Browser", content = "Already at HEAD", timeout = 2 })
    end
    return
  end
  
  -- Navigate to HEAD (index 1)
  navigate_to_index(1)
  
  -- If we were in a temp worktree, cleanup after navigation
  if state.is_temp_worktree then
    cleanup()
  end
end

-- Get commit info
local function get_commit_info(commit)
  local output, err = Command("git")
    :args({ "log", "-1", "--format=%h %s", commit })
    :cwd(state.original_repo)
    :output()
  
  if err then
    return commit:sub(1, 7) .. " (unknown)"
  end
  
  local info = output.stdout:gsub("%s+$", "")
  return info
end

-- Publish commit info via DDS
local function publish_commit_info()
  local info = get_commit_info(state.current_commit)
  local hash = info:match("^%S+")
  local message = info:match("^%S+ (.+)$") or ""
  
  -- Truncate message
  if #message > 30 then
    message = message:sub(1, 30) .. "..."
  end
  
  ps.pub("git-commit-browser:commit", {
    hash = hash,
    message = message,
    is_temp = state.is_temp_worktree or (state.commit_index ~= 1),
    index = state.commit_index,
    total = #state.commit_list
  })
end

-- Interactive commit picker using fzf
local function select_commit()
  if not init() then return end
  
  local commits = {}
  for i, commit in ipairs(state.commit_list) do
    local info = get_commit_info(commit)
    table.insert(commits, info)
  end
  
  -- Use fzf to select
  local input = table.concat(commits, "\n")
  local output, err = Command("sh")
    :args({ "-c", "echo '" .. input:gsub("'", "'\"'\"'") .. "' | fzf --reverse --height=40%" })
    :stdin(Command.PIPED)
    :stdout(Command.PIPED)
    :output()
  
  if err or not output.stdout or output.stdout == "" then
    return
  end
  
  -- Parse selection
  local selected_hash = output.stdout:match("^%S+")
  for i, commit in ipairs(state.commit_list) do
    if commit:sub(1, #selected_hash) == selected_hash then
      navigate_to_index(i)
      break
    end
  end
end

-- Cleanup worktrees
local function cleanup()
  for commit, path in pairs(state.worktrees) do
    Command("git")
      :args({ "worktree", "remove", "--force", path })
      :cwd(state.original_repo)
      :output()
  end
  state.worktrees = {}
end

-- Remove orphaned worktrees older than 24h
local function cleanup_orphaned()
  local temp_base = get_temp_base()
  Command("find")
    :args({ temp_base, "-maxdepth", "1", "-type", "d", "-mtime", "+1", "-exec", "rm", "-rf", "{}", "+" })
    :output()
end

-- Main entry point
return {
  entry = function(self, args)
    if not init() then return end
    
    local action = args[1] or "next"
    
    if action == "next" then
      navigate("next")
    elseif action == "prev" then
      navigate("prev")
    elseif action == "head" then
      goto_head()
    elseif action == "select" then
      select_commit()
    elseif action == "cleanup" then
      cleanup()
    end
  end,
  
  -- Cleanup on plugin unload
  __gc = function()
    if not state.quit_with_q then
      cleanup()
    end
  end
}
