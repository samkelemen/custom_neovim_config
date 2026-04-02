-- /lua/plugins/cxx_module_toggle.lua
--
-- LazyVim plugin spec — drop this file into lua/plugins/ and you're done.
--
-- Toggles all .cpp and .cppm files in the current working directory
-- (recursively, including nested folders) between:
--   • Dev mode    — module lines commented out (//module;, //import std;, …),
--                   dev #includes active
--   • Module mode — module declarations active, dev #includes suppressed (// #include …)
--
-- Keymap : <leader>tm  ("Toggle Modules")  — shown in which-key as "C++ module toggle"
-- Command: :CxxModuleToggle [dir]

-- ---------------------------------------------------------------------------
-- Core logic (kept local, no global pollution)
-- ---------------------------------------------------------------------------

-- Match a line that is a commented-out module statement.
-- Handles both "//keyword" (no space) and "// keyword" (one space).
local function is_commented_module_line(line)
    return line:match("^//%s*module[;%s]")
        or line:match("^//%s*module$")
        or line:match("^//%s*export%s+module")
        or line:match("^//%s*import[%s;]")
        or line:match("^//%s*import$")
end

-- Match a line that is an active (uncommented) module statement.
local function is_active_module_line(line)
    return line:match("^module[;%s]")
        or line:match("^module$")
        or line:match("^export%s+module")
        or line:match("^import%s")
end

local function is_blank_or_comment(line)
    return line:match("^%s*$") or line:match("^%s*//")
end

local function is_preprocessor(line)
    return line:match("^%s*#")
end

local function has_export_prefix(line)
    return line:match("^%s*export%s+")
end

local function strip_export_prefix(line)
    local indent, rest = line:match("^(%s*)(.*)$")
    rest = rest:gsub("^export%s+", "", 1)
    return indent .. rest
end

local function add_export_prefix(line)
    if has_export_prefix(line) then
        return line
    end
    local indent, rest = line:match("^(%s*)(.*)$")
    return indent .. "export " .. rest
end

local function is_export_control_line(line)
    return line:match("^%s*export%s+module") or line:match("^%s*export%s+import")
end

local function sanitize_code_line(line, in_block_comment)
    local out = {}
    local i = 1
    while i <= #line do
        if in_block_comment then
            local close_idx = line:find("*/", i, true)
            if close_idx then
                in_block_comment = false
                i = close_idx + 2
            else
                break
            end
        else
            local line_comment = line:find("//", i, true)
            local block_comment = line:find("/*", i, true)
            if line_comment and (not block_comment or line_comment < block_comment) then
                out[#out + 1] = line:sub(i, line_comment - 1)
                break
            elseif block_comment then
                out[#out + 1] = line:sub(i, block_comment - 1)
                in_block_comment = true
                i = block_comment + 2
            else
                out[#out + 1] = line:sub(i)
                break
            end
        end
    end
    return table.concat(out), in_block_comment
end

local function count_char(str, ch)
    local _, n = str:gsub(vim.pesc(ch), "")
    return n
end

local function count_brace_delta(lines, start_idx, end_idx)
    local comment_state = false
    local delta = 0
    for i = start_idx, end_idx do
        local code
        code, comment_state = sanitize_code_line(lines[i], comment_state)
        delta = delta + count_char(code, "{") - count_char(code, "}")
    end
    return delta
end

local function strip_leading_attributes(text)
    local prev = nil
    while prev ~= text do
        prev = text
        text = text:gsub("^%s*%[%[.-%]%]%s*", "", 1)
    end
    return text
end

local function is_control_statement(text)
    return text:match("^if%s*%(")
        or text:match("^for%s*%(")
        or text:match("^while%s*%(")
        or text:match("^switch%s*%(")
        or text:match("^catch%s*%(")
end

local function is_namespace_decl_line(text)
    local without_export = text:gsub("^%s*export%s+", "", 1)
    without_export = strip_leading_attributes(without_export)
    return without_export:match("^namespace%s") ~= nil or without_export:match("^inline%s+namespace%s") ~= nil
end

local function starts_decl_block(line)
    local text = line:match("^%s*(.-)%s*$")
    if text == "" or is_blank_or_comment(text) or is_preprocessor(text) then
        return false
    end
    if is_active_module_line(text) or is_commented_module_line(text) or is_export_control_line(text) then
        return false
    end

    local without_export = text:gsub("^export%s+", "", 1)
    local stripped = strip_leading_attributes(without_export)

    if stripped:match("^template%s*<") then
        return true
    end
    if stripped:match("^namespace%s") then
        return true
    end
    if stripped:match("^class%s") or stripped:match("^struct%s") or stripped:match("^enum%s") then
        return true
    end
    if stripped:find("%(") then
        return not is_control_statement(stripped)
    end

    return without_export:match("^%[%[") ~= nil
end

local function classify_decl_block(lines, start_idx, end_idx)
    local comment_state = false
    local parts = {}
    for i = start_idx, end_idx do
        local code
        code, comment_state = sanitize_code_line(lines[i], comment_state)
        if code:match("%S") then
            parts[#parts + 1] = code
        end
    end

    local text = table.concat(parts, " "):gsub("%s+", " "):match("^%s*(.-)%s*$")
    if text == "" then
        return nil
    end

    text = text:gsub("^export%s+", "", 1)
    text = strip_leading_attributes(text)

    local after_template = text
    local template_lead, remainder = text:match("^(template%s*<.->%s*)(.*)$")
    if template_lead then
        after_template = remainder
    end
    after_template = strip_leading_attributes(after_template)

    if after_template:match("^namespace%s") then
        return "namespace"
    end
    if after_template:match("^class%s") or after_template:match("^struct%s") or after_template:match("^enum%s") then
        return "type"
    end
    if
        after_template:find("%(")
        and after_template:find("%)")
        and not is_control_statement(after_template)
        and after_template:match("[;{]%s*$")
    then
        return "function"
    end

    return nil
end

local function toggle_export_decls(lines, enable)
    local out = vim.deepcopy(lines)
    local brace_depth = 0
    local comment_state = false
    local i = 1

    while i <= #out do
        local code
        code, comment_state = sanitize_code_line(out[i], comment_state)
        local top_level = brace_depth == 0

        if top_level and is_namespace_decl_line(code) then
            out[i] = enable and add_export_prefix(out[i]) or strip_export_prefix(out[i])
            brace_depth = brace_depth + count_char(code, "{") - count_char(code, "}")
            i = i + 1
        elseif top_level and starts_decl_block(code) then
            local start_idx = i
            local j = i
            local local_comment_state = comment_state
            local local_brace_depth = 0
            local paren_depth = 0
            local angle_depth = 0
            local done = false

            while j <= #out do
                local block_code
                block_code, local_comment_state = sanitize_code_line(out[j], local_comment_state)
                paren_depth = paren_depth + count_char(block_code, "(") - count_char(block_code, ")")
                angle_depth = angle_depth + count_char(block_code, "<") - count_char(block_code, ">")
                local_brace_depth = local_brace_depth + count_char(block_code, "{") - count_char(block_code, "}")

                local trimmed = block_code:match("^%s*(.-)%s*$")
                if trimmed ~= "" and paren_depth <= 0 and angle_depth <= 0 then
                    if trimmed:match(";%s*$") or trimmed:match("{%s*$") then
                        done = true
                        break
                    end
                end
                j = j + 1
            end

            if done then
                local kind = classify_decl_block(out, start_idx, j)
                if kind then
                    out[start_idx] = enable and add_export_prefix(out[start_idx]) or strip_export_prefix(out[start_idx])
                end
                comment_state = local_comment_state
                brace_depth = brace_depth + count_brace_delta(out, start_idx, j)
                i = j + 1
            else
                brace_depth = brace_depth + count_char(code, "{") - count_char(code, "}")
                i = i + 1
            end
        else
            brace_depth = brace_depth + count_char(code, "{") - count_char(code, "}")
            i = i + 1
        end
    end

    return out
end

local function is_dev_mode(lines)
    for _, line in ipairs(lines) do
        if is_commented_module_line(line) then
            return true
        end
        if is_active_module_line(line) then
            return false
        end
    end
    return true -- default: treat as dev mode
end

local function dev_to_module(lines)
    local out = {}
    local past_marker = false

    for _, line in ipairs(lines) do
        if is_commented_module_line(line) then
            past_marker = true
        end

        if is_commented_module_line(line) then
            -- Strip "// " (3 chars) or "//" (2 chars) prefix uniformly
            local stripped = line:match("^//%s(.+)") or line:match("^//(.+)") or ""
            out[#out + 1] = stripped
        elseif past_marker and line:match("^#include") then
            out[#out + 1] = "// " .. line -- suppress dev-only include
        else
            out[#out + 1] = line
        end
    end
    return toggle_export_decls(out, true)
end

local function module_to_dev(lines)
    local out = {}
    for _, line in ipairs(lines) do
        if is_active_module_line(line) then
            out[#out + 1] = "// " .. line -- comment out with space for readability
        elseif line:match("^//%s#include") then
            -- Restore suppressed include: strip leading "// " (3 chars)
            out[#out + 1] = line:sub(4)
        else
            out[#out + 1] = line
        end
    end
    return toggle_export_decls(out, false)
end

local function read_lines(path)
    local f, err = io.open(path, "r")
    if not f then
        return nil, err
    end
    local lines = {}
    for l in f:lines() do
        lines[#lines + 1] = l
    end
    f:close()
    return lines
end

local function write_lines(path, lines)
    local f, err = io.open(path, "w")
    if not f then
        return false, err
    end
    f:write(table.concat(lines, "\n") .. "\n")
    f:close()
    return true
end

local CPP_PATS = { "%.cpp$", "%.cppm$" }

local function is_cxx(fname)
    for _, p in ipairs(CPP_PATS) do
        if fname:match(p) then
            return true
        end
    end
    return false
end

local function find_cxx_files(dir)
    local root = vim.fn.fnamemodify(dir, ":p"):gsub("/$", "")
    local matches = {}

    local function walk(path)
        for name, kind in vim.fs.dir(path) do
            local child = path .. "/" .. name
            if kind == "directory" then
                walk(child)
            elseif kind == "file" and is_cxx(child) then
                matches[#matches + 1] = child
            end
        end
    end

    walk(root)
    table.sort(matches)
    return matches
end

local function toggle_file(path)
    local lines, err = read_lines(path)
    if not lines then
        return ("  ERROR reading %s: %s"):format(path, err)
    end

    -- Capture mode before transformation
    local in_dev = is_dev_mode(lines)
    local new_lines = in_dev and dev_to_module(lines) or module_to_dev(lines)
    local direction = in_dev and "dev → module" or "module → dev"

    local ok, werr = write_lines(path, new_lines)
    if not ok then
        return ("  ERROR writing %s: %s"):format(path, werr)
    end
    return ("  [%s] %s"):format(direction, vim.fn.fnamemodify(path, ":t"))
end

local function toggle_directory(dir)
    dir = dir or vim.fn.getcwd()
    local files = find_cxx_files(dir)

    local msgs = { "cxx_module_toggle  " .. vim.fn.fnamemodify(dir, ":~") }
    local count = 0

    for _, fpath in ipairs(files) do
        msgs[#msgs + 1] = toggle_file(fpath)
        count = count + 1
    end

    msgs[#msgs + 1] = count == 0 and "  (no C++ files found)" or ("  %d file(s) toggled."):format(count)

    vim.notify(table.concat(msgs, "\n"), vim.log.levels.INFO, { title = "C++ Module Toggle" })

    -- Reload open buffers from this directory tree so Neovim picks up changes live
    local abs_dir = vim.fn.fnamemodify(dir, ":p"):gsub("/$", "")
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(bufnr) then
            local bname = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":p"):gsub("/$", "")
            if is_cxx(bname) and (bname == abs_dir or bname:sub(1, #abs_dir + 1) == abs_dir .. "/") then
                vim.api.nvim_buf_call(bufnr, function()
                    vim.cmd("checktime")
                end)
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- LazyVim plugin spec ---------------------------------------------------------------------------

local plugin = {
    -- Virtual plugin: no remote repo needed.
    -- `dir` points at the Neovim config root so Lazy can find/manage it.
    dir = vim.fn.stdpath("config"),
    name = "cxx-module-toggle",

    -- Lazy-load: only activate when a C/C++ buffer is opened.
    ft = { "c", "cpp" },

    -- Declare keys here so LazyVim / which-key registers them before the
    -- plugin fully loads, and so :Lazy shows them in the plugin detail view.
    keys = {
        {
            "<leader>tm",
            function()
                toggle_directory(vim.fn.getcwd())
            end,
            desc = "C++ module toggle (cwd)",
            -- Falls under LazyVim's default <leader>t "toggle" which-key group.
        },
    },

    config = function()
        -- Ex command — useful from the command line or other scripts.
        vim.api.nvim_create_user_command("CxxModuleToggle", function(o)
            toggle_directory(o.args ~= "" and o.args or vim.fn.getcwd())
        end, {
            nargs = "?",
            complete = "dir",
            desc = "Toggle C++ module/dev mode (optional directory argument)",
        })
    end,
}

plugin.__test = {
    classify_decl_block = classify_decl_block,
    toggle_export_decls = toggle_export_decls,
    dev_to_module = dev_to_module,
    module_to_dev = module_to_dev,
}

return plugin

-- ---------------------------------------------------------------------------
-- Installation
--   1. Copy this file to:
--        ~/.config/nvim/lua/plugins/cxx_module_toggle.lua
--   2. Restart Neovim (LazyVim auto-discovers everything under lua/plugins/).
--      Or run :Lazy sync if you want to be explicit.
--
-- Usage
--   <leader>tm              toggle all .cpp/.cppm files in the current working directory tree
--   :CxxModuleToggle        same via Ex command
--   :CxxModuleToggle ~/src  target a specific directory
--
-- which-key
--   <leader>t is LazyVim's built-in "toggle" group, so <leader>tm appears
--   there automatically with the label "C++ module toggle (cwd)".
-- ---------------------------------------------------------------------------
