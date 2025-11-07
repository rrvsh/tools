vim.o.relativenumber = true
vim.o.number = true
vim.o.expandtab = true -- insert tabs with spaces
vim.o.smarttab = true -- start of line uses shiftwidth, else tabstop
vim.o.tabstop = 2 -- amount of spaces a tab character represents
vim.o.softtabstop = 2 -- amount of spaces tab should indent
vim.o.shiftwidth = 2 -- amount of spaces builtins use by default
vim.keymap.set("v", "Y", '"+y') -- copy to clipboard on shift y
vim.keymap.set({ "n", "v" }, "<leader>s", vim.cmd("update"))
