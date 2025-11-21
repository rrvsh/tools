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
vim.lsp.enable("nil_ls")
vim.lsp.enable("rust_analyzer")
vim.lsp.config('rust_analyzer', {
  settings = {
    ['rust-analyzer'] = {
      check = {
        command = "clippy";
      }
    }
  }
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
