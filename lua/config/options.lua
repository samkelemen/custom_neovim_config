-- lua/config/options.lua
vim.opt.number = true
vim.opt.cursorline = true
vim.opt.relativenumber = true
vim.opt.shiftwidth = 4

-- Yank to the system clipboard
vim.opt.clipboard = "unnamedplus"

-- Set the colorscheme to habamax
vim.cmd.colorscheme("habamax")

-- Don't change the cwd when I move into a file
vim.opt.autochdir = false

-- Highlight yanked text
vim.api.nvim_create_autocmd("TextYankPost", {
    callback = function()
        vim.highlight.on_yank({ higroup = "IncSearch", timeout = 150 })
    end,
})
