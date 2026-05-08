-- lua/plugins/snacks.lua
return {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    ---@type snacks.Config
    opts = {
        image = { enabled = true },
        -- bonus: makes opening large/binary files faster
        bigfile = { enabled = true },
        quickfile = { enabled = true },
    },
}
