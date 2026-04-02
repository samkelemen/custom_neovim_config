-- lua/plugins/colorful_winsep.lua
return {
    "nvim-zh/colorful-winsep.nvim",
    event = { "WinNew" },
    -- Use 'opts' instead of 'config' to avoid the "table format" error
    opts = {
        border = "bold",
        highlight = "#e8b361",
        indicator_for_2wins = {
            position = "center",
            symbols = {
                start_left = "󱞬",
                end_left = "󱞪",
                start_down = "󱞾",
                end_down = "󱟀",
                start_up = "󱞢",
                end_up = "󱞤",
                start_right = "󱞨",
                end_right = "󱞦",
            },
        },
    },
}
