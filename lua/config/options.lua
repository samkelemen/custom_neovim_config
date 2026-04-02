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

-- Code folding via treesitter
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "nvim_treesitter#foldexpr()"
vim.opt.foldenable = false  -- don't fold on open

-- Show full diagnostic messages inline
vim.diagnostic.config({
    virtual_text = {
        prefix = "",
        format = function(d)
            local icons = { ERROR = " ", WARN = " ", INFO = " ", HINT = " " }
            return icons[vim.diagnostic.severity[d.severity]] .. d.message
        end,
    },
    signs = {
        text = {
            [vim.diagnostic.severity.ERROR] = " ",
            [vim.diagnostic.severity.WARN] = " ",
            [vim.diagnostic.severity.INFO] = " ",
            [vim.diagnostic.severity.HINT] = " ",
        },
    },
    underline = true,
})

-- Highlight yanked text
vim.api.nvim_create_autocmd("TextYankPost", {
    callback = function()
        vim.highlight.on_yank({ higroup = "IncSearch", timeout = 150 })
    end,
})
