-- luacheck: globals vim Snacks
require("snacks")

-- VISUALS
Snacks.indent.enable()

-- UTILS
local function git_root()
	local handle = io.popen("git rev-parse --show-toplevel 2>/dev/null")
	local result = handle:read("*a")
	handle:close()
	return vim.fn.trim(result)
end

-- OPTIONS
vim.o.relativenumber = true
vim.o.number = true
vim.o.expandtab = true -- insert tabs with spaces
vim.o.smarttab = true -- start of line uses shiftwidth, else tabstop
vim.o.tabstop = 2 -- amount of spaces a tab character represents
vim.o.softtabstop = 2 -- amount of spaces tab should indent
vim.o.shiftwidth = 2 -- amount of spaces builtins use by default

-- KEYMAPS
vim.keymap.set("v", "Y", '"+y') -- copy to clipboard on shift y
vim.keymap.set({ "n", "v" }, "<leader>s", vim.cmd("update"))
vim.keymap.set("n", "<leader>fg", Snacks.picker.grep)
vim.keymap.set("n", "<leader>ff", function()
	Snacks.picker.files({ dirs = { git_root() } })
end, { desc = "search git repo" })
