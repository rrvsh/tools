-- luacheck: globals vim

-- PLUGINS

require("mini.pick").setup()
require("fidget").setup()
require("fff").setup()
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
vim.o.ignorecase = true -- case insensitive search
vim.o.smartcase = true -- case sensitive search if it includes capital letters
vim.o.smarttab = true -- start of line uses shiftwidth, else tabstop
vim.o.softtabstop = 2 -- amount of space characters tab should indent
vim.o.tabstop = 2 -- amount of space characters a tab character represents
vim.o.termguicolors = true
vim.o.undofile = true
vim.o.signcolumn = "number"

-- KEYMAPS

--- PASSIVE
vim.keymap.set("n", "", "zz", { desc = "Center screen on scroll down" })
vim.keymap.set("n", "", "zz", { desc = "Center screen on scroll up" })
vim.keymap.set("n", "n", "nzz", { desc = "Center screen on next search" })
vim.keymap.set("n", "N", "Nzz", { desc = "Center screen on prev search" })

--- ACTIVE
vim.keymap.set("n", "<leader>ff", function()
	require("fff").find_files()
end, { desc = "FFF: Files" })

vim.keymap.set("n", "<leader>fg", function()
	require("fff").live_grep()
end, { desc = "FFF: Live Grep" })

vim.keymap.set("n", "<leader>ee", function()
	local path = vim.fn.input("EPUB path: ", "", "file")
	if path ~= "" then
		require("epub").open_epub(path)
	end
end, { desc = "Epub: Open file" })

vim.keymap.set("n", "<leader>en", "]c", { desc = "Epub: Next chapter" })
vim.keymap.set("n", "<leader>ep", "[c", { desc = "Epub: Prev chapter" })
vim.keymap.set("n", "<leader>et", "gt", { desc = "Epub: Table of contents" })
vim.keymap.set("n", "<leader>ei", "gi", { desc = "Epub: Open image" })

vim.keymap.set("n", "<leader>la", function()
	vim.lsp.buf.code_action()
end, { desc = "Code Actions" })

vim.keymap.set("n", "<leader>lh", function()
	vim.lsp.buf.hover()
end, { desc = "Hover" })

vim.keymap.set("n", "<leader>lgd", function()
	vim.lsp.buf.definition()
end, { desc = "Go to definition" })

vim.keymap.set("n", "<leader>lgr", function()
	vim.lsp.buf.references()
end, { desc = "List all references" })

vim.keymap.set("n", "<leader>lf", function()
	vim.lsp.buf.format()
end, { desc = "Format" })

vim.keymap.set("n", "<leader>lr", function()
	vim.lsp.buf.rename()
end, { desc = "Rename all references" })

vim.keymap.set("n", "<leader>ra", [[:%s/\<\>//gI<Left><Left><Left>]], {
	desc = "Change all file refs",
})

vim.keymap.set("n", "<leader>tt", ":Yazi<CR>", { desc = "Open Yazi" })
vim.keymap.set("n", "<leader>w", ":w ++p<CR>", { desc = "Write all" })
vim.keymap.set("v", "<leader>y", '"+y', { desc = "Copy to system clipboard" })

local function edit_note(path)
	vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
	vim.cmd.edit(vim.fn.fnameescape(path))
end

local function run_process(dir)
	local command = "process"
	if dir then
		command = command .. " " .. vim.fn.shellescape(dir)
	end

	vim.cmd("split | terminal " .. command)
end

vim.keymap.set("n", "<leader>nd", function()
	edit_note(vim.fn.expand("~/0_library/notes/daily/" .. os.date("%F") .. ".md"))
end, { desc = "Open daily note" })

vim.keymap.set("n", "<leader>nm", function()
	edit_note(vim.fn.expand("~/0_library/notes/monthly/" .. os.date("%Y-%m") .. ".md"))
end, { desc = "Open monthly note" })

vim.keymap.set("n", "<leader>np", function()
	run_process()
end, { desc = "Process notes picker" })

vim.keymap.set("n", "<leader>nP", function()
	run_process(vim.fn.expand("~/1_repos/pedia"))
end, { desc = "Pedia notes picker" })

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
