-- luacheck: globals vim Snacks
require("snacks")

-- VISUALS
Snacks.indent.enable()
vim.o.relativenumber = true
vim.o.number = true
vim.opt.termguicolors = true

-- UTILS
local function git_root()
	local handle = io.popen("git rev-parse --show-toplevel 2>/dev/null")
	local result = handle:read("*a")
	handle:close()
	return vim.fn.trim(result)
end

-- INPUT
vim.o.expandtab = true -- insert tabs with space characters
vim.o.smarttab = true -- start of line uses shiftwidth, else tabstop
vim.o.tabstop = 2 -- amount of space characters a tab character represents
vim.o.softtabstop = 2 -- amount of space characters tab should indent
vim.o.shiftwidth = 2 -- amount of space characters builtins use by default
vim.g.mapleader = " "
vim.keymap.set("v", "Y", '"+y') -- copy to clipboard on shift y
vim.keymap.set("n", "<leader>ra", [[:%s/\<\>//gI<Left><Left><Left>]]) -- edit all references in file
vim.keymap.set("n", "<leader>fg", Snacks.picker.grep)
vim.keymap.set("n", "<leader>ff", function()
	Snacks.picker.files({ dirs = { git_root() } })
end, { desc = "search git repo" })

-- MISC

vim.o.undofile = true
