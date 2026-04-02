return {
    {
        "olimorris/codecompanion.nvim",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "nvim-treesitter/nvim-treesitter",
        },
        opts = {
            display = {
                chat = {
                    window = {
                        layout = "vertical",
                        position = "right",
                        width = 0.35,
                    },
                },
            },
            adapters = {
                anthropic = function()
                    return require("codecompanion.adapters").extend("anthropic", {
                        schema = {
                            model = {
                                default = "claude-4-6-sonnet", -- Or your preferred model
                            },
                        },
                    })
                end,
            },
        },
    },
}
