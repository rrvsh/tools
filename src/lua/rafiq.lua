-- luacheck: globals vim

-- PLUGINS

require("mini.pick").setup()
require("fidget").setup()
local yazi = require("yazi")
vim.g.loaded_netrwPlugin = 1
vim.api.nvim_create_autocmd("UIEnter", {
	callback = function()
		yazi.setup({
			open_for_directories = true,
		})
	end,
})

-- OPTIONS

vim.g.mapleader = " "

vim.o.cursorline = true
vim.o.expandtab = true -- insert tabs with space characters
vim.o.number = true
vim.o.relativenumber = true
vim.o.shiftwidth = 2 -- amount of space characters builtins use by default
vim.o.smartcase = true
vim.o.smarttab = true -- start of line uses shiftwidth, else tabstop
vim.o.softtabstop = 2 -- amount of space characters tab should indent
vim.o.tabstop = 2 -- amount of space characters a tab character represents
vim.o.termguicolors = true
vim.o.undofile = true
vim.o.undofile = true
vim.o.winborder = "rounded"
vim.o.signcolumn = "number"

-- KEYMAPS

vim.keymap.set("n", "", "zz", { desc = "Center screen on scroll down" })
vim.keymap.set("n", "", "zz", { desc = "Center screen on scroll up" })
vim.keymap.set("n", "<leader>tt", ":Yazi<CR>", { desc = "Open Yazi" })
vim.keymap.set("v", "<leader>y", '"+y', { desc = "Copy to system clipboard" })
vim.keymap.set("n", "<leader>w", ":w ++p<CR>", { desc = "Write all" })
vim.keymap.set("n", "<leader>h", ":help ", { desc = "Open help command" })
vim.keymap.set("n", "<leader>ff", ":Pick files<CR>", { desc = "Picker: Files" })
vim.keymap.set("n", "<leader>fg", ":Pick grep_live<CR>", { desc = "Picker: Files" })
vim.keymap.set("n", "<leader>la", function()
	vim.lsp.buf.code_action()
end, { desc = "Code Actions" })
vim.keymap.set("n", "<leader>lh", function()
	vim.lsp.buf.hover()
end, { desc = "Hover" })
vim.keymap.set("n", "<leader>lr", function()
	vim.lsp.buf.rename()
end, { desc = "Rename all references" })
vim.keymap.set("n", "<leader>lgd", function()
	vim.lsp.buf.definition()
end, { desc = "Go to definition" })
vim.keymap.set("n", "<leader>lgr", function()
	vim.lsp.buf.references()
end, { desc = "List all references" })
vim.keymap.set("n", "<leader>lf", function()
	vim.lsp.buf.format()
end, { desc = "Format" })
vim.keymap.set("n", "<leader>ra", [[:%s/\<\>//gI<Left><Left><Left>]], {
	desc = "Change all file refs",
})
vim.keymap.set("n", "<leader>sil", "vi[:sort<CR>", { desc = "Sort in []" })

-- LSP

vim.diagnostic.config({ virtual_text = { current_line = true } })
vim.lsp.enable("pyright")
vim.lsp.enable("ruff")
vim.lsp.enable("nil_ls")
vim.lsp.enable("rust_analyzer")
vim.lsp.config("rust_analyzer", {
	settings = {
		["rust-analyzer"] = {
			check = {
				command = "clippy",
			},
		},
	},
})
vim.lsp.enable("stylua")
vim.lsp.enable("lua_ls")
vim.lsp.config("lua_ls", {
	on_init = function(client)
		if client.workspace_folders then
			local path = client.workspace_folders[1].name
			if
				path ~= vim.fn.stdpath("config")
				and (vim.uv.fs_stat(path .. "/.luarc.json") or vim.uv.fs_stat(path .. "/.luarc.jsonc"))
			then
				return
			end
		end

		client.config.settings.Lua = vim.tbl_deep_extend("force", client.config.settings.Lua, {
			runtime = {
				version = "LuaJIT",
				path = {
					"lua/?.lua",
					"lua/?/init.lua",
				},
			},
			workspace = {
				checkThirdParty = false,
				library = { vim.env.VIMRUNTIME },
			},
		})
	end,
	settings = {
		Lua = {
			format = { enable = false },
		},
	},
})

-- MARKDOWN TIMEBLOCK HIGHLIGHT
-- Goal: for markdown daily-planner files that contain one time slot per line in the
-- shape "HHMM-HHMM:" (e.g., "0630-0700:"), automatically highlight the single line
-- whose interval contains the current wall-clock time. This keeps the current slot
-- visually pinned as you work, even if the buffer is unchanged, by refreshing every
-- minute and on common buffer events.

-- Dedicated namespace so highlights can be cleared without touching other plugins.
local timeblock_ns = vim.api.nvim_create_namespace("rafiq_timeblock")

-- Link the active-slot highlight to IncSearch for high contrast; users can override
-- this link in their colorscheme if desired.
vim.api.nvim_set_hl(0, "TimeBlockNow", { link = "IncSearch" })

-- Parse a single line that looks like "HHMM-HHMM:" and return start/end in minutes
-- since midnight. Any line that doesn't match the pattern is ignored.
local function parse_timeblock(line)
	local start_s, end_s = line:match("^%s*(%d%d%d%d)%-(%d%d%d%d):")
	if not start_s then
		return nil -- fast-exit on non-matching lines
	end

	-- Convert both timestamps to minutes to simplify comparison math.
	local start_minutes = tonumber(start_s:sub(1, 2)) * 60 + tonumber(start_s:sub(3, 4))
	local end_minutes = tonumber(end_s:sub(1, 2)) * 60 + tonumber(end_s:sub(3, 4))

	if not start_minutes or not end_minutes then
		return nil -- defensive: malformed numbers should not cause errors downstream
	end

	return start_minutes, end_minutes
end

-- Core routine: clear any prior highlight in this buffer, detect whether the buffer
-- is markdown, and then find the first line whose interval contains the current time
-- (inclusive of start, exclusive of end) and highlight it.
local function highlight_current_block(bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return -- buffer may have been wiped while timer fired
	end

	-- Only act on markdown files; clear stale highlights when leaving markdown.
	if vim.bo[bufnr].filetype ~= "markdown" then
		vim.api.nvim_buf_clear_namespace(bufnr, timeblock_ns, 0, -1)
		return
	end

	-- Reset prior highlights each run to ensure only one line is marked.
	vim.api.nvim_buf_clear_namespace(bufnr, timeblock_ns, 0, -1)

	-- Grab current wall time once per run (local time; OS clock governs correctness).
	local now = os.date("*t")
	local minutes_now = now.hour * 60 + now.min

	-- Iterate every line; buffers are expected to be small (daily agenda), so O(n) is fine.
	for idx, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
		local start_minutes, end_minutes = parse_timeblock(line)

		-- Inclusive start, exclusive end matches typical timeblock semantics.
		if start_minutes and end_minutes and start_minutes <= minutes_now and minutes_now < end_minutes then
			-- Highlight the entire line; column range 0,-1 covers full text.
			vim.api.nvim_buf_add_highlight(bufnr, timeblock_ns, "TimeBlockNow", idx - 1, 0, -1)
			break -- stop after first matching block; assumes non-overlapping slots
		end
	end
end

-- Respond to edits, writes, buffer switches, and focus changes so the highlight stays
-- in sync with both file content and OS time when re-entering Neovim.
vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "TextChanged", "TextChangedI", "FocusGained" }, {
	callback = function(args)
		highlight_current_block(args.buf)
	end,
})

-- Timer: refresh once a minute so the highlight advances even if the buffer is idle.
-- Start immediately (0ms) to initialize on launch, then every 60s thereafter.
local timeblock_timer = vim.uv.new_timer()
timeblock_timer:start(
	0,
	60 * 1000,
	vim.schedule_wrap(function()
		highlight_current_block(vim.api.nvim_get_current_buf())
	end)
)

-- Cleanly stop/close the timer on exit to avoid stray libuv handles during shutdown.
vim.api.nvim_create_autocmd("VimLeavePre", {
	callback = function()
		if timeblock_timer and not timeblock_timer:is_closing() then
			timeblock_timer:stop()
			timeblock_timer:close()
		end
	end,
})
