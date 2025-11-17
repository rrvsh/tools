-- luacheck: globals vim
vim.pack.add({
	{ src = "https://github.com/neovim/nvim-lspconfig" },
	{ src = "https://github.com/folke/which-key.nvim" },
})

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
vim.keymap.set("v", "<leader>y", '"+y', { desc = "Copy to system clipboard" })
vim.keymap.set("n", "<leader>w", ":update ++p<CR>", { desc = "Write file if update" })
vim.keymap.set("n", "<leader>h", ":help ", { desc = "Open help command" })
vim.keymap.set("n", "<leader>so", ":source<CR>", { desc = "Source current lua file" })
vim.keymap.set("n", "<leader>la", function()
	vim.lsp.buf.code_action()
end, { desc = "Code Actions" })
vim.keymap.set("n", "<leader>lh", function()
	vim.lsp.buf.hover()
end, { desc = "Hover" })
vim.keymap.set("n", "<leader>lr", function()
	vim.lsp.buf.rename()
end, { desc = "Rename all references" })
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

-- AUTOCMD

vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged", "CursorHold" }, {
	pattern = "*",
	callback = function()
		local buf = vim.api.nvim_get_current_buf()
		local before = vim.api.nvim_buf_get_changedtick(buf)

		if vim.bo.filetype == "rust" then
			vim.cmd("silent write")
		else
			vim.cmd("silent update")
		end

		local after = vim.api.nvim_buf_get_changedtick(buf)

		if after > before then
			local name = vim.api.nvim_buf_get_name(buf)
			local time = os.date("%H:%M:%S")
			vim.api.nvim_echo({ { "Wrote: " .. name .. " at " .. time } }, false, {})
		end
	end,
})

-- LSP

vim.diagnostic.config({ virtual_text = { current_line = true } })
vim.lsp.enable("nil_ls")
vim.lsp.enable("rust_analyzer")
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
