-- lua/config/keymaps.lua

-- Set leader key to space
vim.g.mapleader = " "

-- Open explorer with <leader>E
vim.keymap.set("n", "<leader>E", vim.cmd.Ex)

-- Use jj for returning to normal mode
vim.keymap.set("i", "jj", "<Esc>")
vim.keymap.set("t", "jj", [[<C-\><C-n>]], { desc = "Exit terminal mode" })

-- Use command + hjkl to move between panes
vim.keymap.set("n", "<C-h>", "<C-w>h", opts)
vim.keymap.set("n", "<C-j>", "<C-w>j", opts)
vim.keymap.set("n", "<C-k>", "<C-w>k", opts)
vim.keymap.set("n", "<C-l>", "<C-w>l", opts)
vim.keymap.set("t", "<C-h>", "<C-\\><C-n><C-w>h", opts)
vim.keymap.set("t", "<C-j>", "<C-\\><C-n><C-w>j", opts)
vim.keymap.set("t", "<C-k>", "<C-\\><C-n><C-w>k", opts)
vim.keymap.set("t", "<C-l>", "<C-\\><C-n><C-w>l", opts)

-- Open floating neotree window with <leader>e
local opts = { noremap = true, silent = true }

vim.keymap.set("n", "<leader>e", function()
    local current_file = vim.fn.expand("%:p")
    if current_file ~= "" and vim.fn.filereadable(current_file) == 1 then
        vim.cmd("Neotree toggle reveal_file=" .. current_file .. " position=float")
    else
        vim.cmd("Neotree toggle position=float dir=" .. vim.fn.getcwd())
    end
end, opts)

-- Set leader + a to select all
vim.keymap.set("n", "<leader>a", "ggVG", { noremap = true, silent = true })

-- Code companion chat
vim.keymap.set({ "n", "v" }, "<C-a>", "<cmd>CodeCompanionChat<CR>", { desc = "Open CodeCompanion Chat" })
vim.keymap.set({ "n", "v" }, "<Leader>cai", "<cmd>CodeCompanionChat Toggle<CR>", { desc = "Toggle a chat buffer" })
vim.keymap.set({ "v" }, "<LocalLeader>cai", "<cmd>CodeCompanionChat Add<CR>", { desc = "Add code to a chat buffer" })

-- Open/toggle a vertical terminal in insert mode on the right of the screen with <leader>v
local vertical_term_buf = nil
local vertical_term_win = nil

vim.keymap.set("n", "<leader>v", function()
    if vertical_term_win ~= nil and vim.api.nvim_win_is_valid(vertical_term_win) then
        vim.api.nvim_win_close(vertical_term_win, false)
        vertical_term_win = nil
    else
        vim.cmd("rightbelow vsplit")
        vertical_term_win = vim.api.nvim_get_current_win()
        local width = math.floor(vim.o.columns * 0.35)
        vim.api.nvim_win_set_width(vertical_term_win, width)
        if vertical_term_buf ~= nil and vim.api.nvim_buf_is_valid(vertical_term_buf) then
            vim.api.nvim_win_set_buf(vertical_term_win, vertical_term_buf)
        else
            vim.cmd("terminal")
            vertical_term_buf = vim.api.nvim_get_current_buf()
        end
        vim.cmd("startinsert")
    end
end, opts)

-- Keymaps for bufferline
vim.keymap.set("n", "H", ":BufferLineCyclePrev<CR>", opts)
vim.keymap.set("n", "L", ":BufferLineCycleNext<CR>", opts)
vim.keymap.set("n", "<leader>x", ":bdelete<CR>", opts)
