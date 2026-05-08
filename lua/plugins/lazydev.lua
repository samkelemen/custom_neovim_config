-- lua/plugins/lazydev.lua
return {
    "folke/lazydev.nvim",
    ft = "lua", -- only loads when editing Lua files
    opts = {
        library = {
            -- adds type info for vim.uv (libuv)
            { path = "${3rd}/luv/library", words = { "vim%.uv" } },
            -- loads snacks types whenever your code mentions `Snacks`
            { path = "snacks.nvim", words = { "Snacks" } },
        },
    },
}
