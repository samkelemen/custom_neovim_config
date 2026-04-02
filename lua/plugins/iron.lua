-- lua/plugins/iron.lua
return {
    "https://github.com/Vigemus/iron.nvim",
    config = function()
        local iron = require("iron.core")
        local view = require("iron.view")
        local common = require("iron.fts.common")
        iron.setup({
            config = {
                scratch_repl = true,
                repl_definition = {
                    python = {
                        command = { "python3" },
                        format = common.bracketed_paste_python,
                        block_dividers = { "# %%", "#%%" },
                        env = { PYTHON_BASIC_REPL = "1" },
                    },
                },
                dap_integration = true,
                repl_open_cmd = view.split.vertical.botright("35%"),
            },
            keymaps = {
                toggle_repl = "<space>rr",
                restart_repl = "<space>rR",
                send_file = "<space>sf",
                send_line = "<space>sl",
                send_paragraph = "<space>sp",
                send_code_block = "<space>sb",
                send_code_block_and_move = "<space>sn",
                interrupt = "<space>s<space>",
                exit = "<space>sq",
                clear = "<space>cl",
            },
            highlight = {
                italic = true,
            },
            ignore_blank_lines = true,
        })
        vim.keymap.set("n", "<space>rf", "<cmd>IronFocus<cr>")
    end,
}
