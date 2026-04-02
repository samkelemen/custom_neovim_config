-- lua/config/neotree.lua
return {
    {
        "nvim-neo-tree/neo-tree.nvim",
        branch = "v3.x",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "MunifTanjim/nui.nvim",
            "nvim-tree/nvim-web-devicons",
        },
        lazy = false,
        config = function()
            require("neo-tree").setup({
                window = {
                    position = "float",
                },
                filesystem = {
                    bind_to_cwd = true,
                    cwd_target = {
                        sidebar = "tab",
                        current = "window",
                    },
                },
                event_handlers = {
                    {
                        event = "neo_tree_window_after_open",
                        handler = function()
                            Neotree_is_open = true
                        end,
                    },
                    {
                        event = "neo_tree_window_after_close",
                        handler = function()
                            Neotree_is_open = false
                        end,
                    },
                },
            })

            vim.api.nvim_create_autocmd("VimEnter", {
                callback = function()
                    vim.schedule(function()
                        local current_file = vim.fn.expand("%:p")
                        if current_file == "" then
                            local path = vim.fn.getcwd()
                            vim.cmd("Neotree float dir=" .. path)
                            Neotree_is_open = true
                        end
                    end)
                end,
            })
        end,
    },
}
