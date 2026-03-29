# Neovim/Lua Configuration Guidelines

## Checks

```bash
just check-lua    # Check lua formatting
just lint-lua     # Lint lua files
```

## Code Style

Formatting: Uses `stylua`.

Linting: Uses `luacheck`.

Config Location: Neovim config is in `nvim/rafiq.lua` and sourced via home-manager.

## Key Patterns

### LSP Configuration
```lua
vim.lsp.enable("rust_analyzer")
vim.lsp.config("rust_analyzer", {
    settings = {
        ["rust-analyzer"] = {
            check = { command = "clippy" },
        },
    },
})
```

### Plugin Setup
```lua
require("mini.pick").setup()
require("fff").setup()
```

### Keymaps
```lua
vim.keymap.set("n", "<leader>ff", function()
    require("fff").find_files()
end, { desc = "FFF: Files" })
```

## Plugins Used

- `fff-nvim` - File picker
- `fidget-nvim` - LSP progress
- `gitsigns-nvim` - Git integration
- `mini.nvim` - Mini plugins suite (pick, etc.)
- `nvim-lspconfig` - LSP client
- `plenary.nvim` - Lua utilities
- `which-key-nvim` - Keymap helper
- `yazi-nvim` - File manager integration
- `epub.nvim` - EPUB reader
