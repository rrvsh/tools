-- luacheck: globals vim

-- PLUGINS

require("mini.pick").setup()
require("fidget").setup()
require("fff").setup()
local epub = require("epub")
epub.setup({
	auto_open = true,
})
local yazi = require("yazi")
vim.g.loaded_netrwPlugin = 1
vim.api.nvim_create_autocmd("UIEnter", {
	callback = function()
		yazi.setup({
			open_for_directories = true,
		})
	end,
})

-- CUSTOM LOGIC

-- Custom Picker

local function edit_note(path)
	vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
	if vim.fn.filereadable(path) == 0 then
		vim.fn.writefile({}, path)
	end
	vim.cmd.edit(vim.fn.fnameescape(path))
end

local function open_note_picker(dir)
	local expanded_dir = vim.fn.expand(dir)
	vim.fn.mkdir(expanded_dir, "p")
	vim.g.rafiq_note_create_dir = expanded_dir
	require("fff").find_files_in_dir(expanded_dir)
end

local function create_note_from_picker_query()
	local picker = require("fff.picker_ui")
	local query = (picker.state and picker.state.query) or ""
	local dir = vim.g.rafiq_note_create_dir

	if dir == nil or dir == "" then
		vim.notify("No note directory set for picker", vim.log.levels.WARN)
		return
	end

	if query == "" then
		vim.notify("Type a note name first", vim.log.levels.WARN)
		return
	end

	local name = query
	if not name:match("%.md$") then
		name = name .. ".md"
	end

	picker.close()
	dir = dir:gsub("/+$", "") -- remove all trailing frontslashes
	edit_note(dir .. "/" .. name)
end

vim.api.nvim_create_autocmd("FileType", {
	pattern = "fff_input",
	callback = function(event)
		local opts = { buffer = event.buf, noremap = true, silent = true }
		vim.keymap.set({ "i", "n" }, "<M-CR>", create_note_from_picker_query, opts)
		vim.keymap.set({ "i", "n" }, "<C-y>", create_note_from_picker_query, opts)
	end,
})

-- Indentation Rules ---

vim.cmd("filetype plugin indent on")
local indent_group = vim.api.nvim_create_augroup("IndentationRules", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
	group = indent_group,
	pattern = "*",
	callback = function()
		vim.bo.expandtab = true
		vim.bo.softtabstop = 2
		vim.bo.shiftwidth = 2
		vim.bo.tabstop = 2
	end,
})

-- OPTIONS

vim.g.mapleader = " "

vim.o.cursorline = true
vim.o.ignorecase = true -- case insensitive search
vim.o.number = true
vim.o.relativenumber = true
vim.o.signcolumn = "yes"
vim.o.smartcase = true -- case sensitive search if it includes capital letters
vim.o.termguicolors = true
vim.o.undofile = true

-- KEYMAPS

--- PASSIVE
vim.keymap.set("n", "", "zz", { desc = "Center screen on scroll down" })
vim.keymap.set("n", "", "zz", { desc = "Center screen on scroll up" })
vim.keymap.set("n", "n", "nzz", { desc = "Center screen on next search" })
vim.keymap.set("n", "N", "Nzz", { desc = "Center screen on prev search" })

--- ACTIVE
vim.keymap.set("n", "<leader>gh", ":Gitsigns preview_hunk<CR>", { desc = "Preview diff in popup" })
vim.keymap.set("n", "<leader>gj", ":Gitsigns nav_hunk next<CR>", { desc = "Go to next hunk" })
vim.keymap.set("n", "<leader>gk", ":Gitsigns nav_hunk prev<CR>", { desc = "Go to previous hunk" })
vim.keymap.set("n", "<leader>gr", ":Gitsigns reset_hunk<CR>", { desc = "Restore hunk" })
vim.keymap.set("n", "<leader>gs", ":Gitsigns stage_hunk<CR>", { desc = "Stage hunk" })
vim.keymap.set("n", "<leader>ee", function()
	local path = vim.fn.input("EPUB path: ", "", "file")
	if path ~= "" then
		epub.open_epub(path)
	end
end, { desc = "Epub: Open file" })
vim.keymap.set("n", "<leader>ei", "gi", { desc = "Epub: Open image" })
vim.keymap.set("n", "<leader>en", "]c", { desc = "Epub: Next chapter" })
vim.keymap.set("n", "<leader>ep", "[c", { desc = "Epub: Prev chapter" })
vim.keymap.set("n", "<leader>et", "gt", { desc = "Epub: Table of contents" })
vim.keymap.set("n", "<leader>ff", function()
	require("fff").find_files()
end, { desc = "FFF: Files" })
vim.keymap.set("n", "<leader>fg", function()
	require("fff").live_grep()
end, { desc = "FFF: Live Grep" })
vim.keymap.set("n", "<leader>la", function()
	vim.lsp.buf.code_action()
end, { desc = "Code Actions" })
vim.keymap.set("n", "<leader>lf", function()
	vim.lsp.buf.format()
end, { desc = "Format" })
vim.keymap.set("n", "<leader>lgd", function()
	vim.lsp.buf.definition()
end, { desc = "Go to definition" })
vim.keymap.set("n", "<leader>lgr", function()
	vim.lsp.buf.references()
end, { desc = "List all references" })
vim.keymap.set("n", "<leader>lh", function()
	vim.lsp.buf.hover()
end, { desc = "Hover" })
vim.keymap.set("n", "<leader>lr", function()
	vim.lsp.buf.rename()
end, { desc = "Rename all references" })
vim.keymap.set("n", "<leader>nd", function()
	edit_note(vim.fn.expand("~/0_library/logs/daily/" .. os.date("%d%m%Y") .. ".md"))
end, { desc = "Open daily log" })
vim.keymap.set("n", "<leader>nD", function()
	open_note_picker("~/0_library/logs/daily")
end, { desc = "Picker: Daily Logs" })
vim.keymap.set("n", "<leader>np", function()
	open_note_picker("~/0_library/logs/process/")
end, { desc = "Picker: Process Logs" })
vim.keymap.set("n", "<leader>ra", [[:%s/\<\>//gI<Left><Left><Left>]], {
	desc = "Change all file refs",
})
vim.keymap.set("n", "<leader>tt", ":Yazi<CR>", { desc = "Open Yazi" })
vim.keymap.set("n", "<leader>w", ":w ++p<CR>", { desc = "Write all" })
vim.keymap.set("v", "<leader>y", '"+y', { desc = "Copy to system clipboard" })

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
