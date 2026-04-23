-- lua/plugins/cxx_modules.lua
--
-- C++23 module-aware editing support.
--
-- Gives clangd the flags and root-detection it needs to index module-based
-- projects (.cppm interfaces, .cpp implementations, `import` statements) and
-- ships two helper commands for turning a CMake project into something clangd
-- can actually read.
--
-- Commands:
--   :CxxModulesConfigure     run cmake -G Ninja with module scanning enabled
--                            and symlink compile_commands.json to the project
--                            root, then restart any clangd client so it
--                            re-indexes against the fresh DB.
--   :CxxModulesInitClangd    drop a .clangd config at the project root
--                            (refuses to overwrite an existing file).

-- ---------------------------------------------------------------------------
-- Utilities
-- ---------------------------------------------------------------------------

local uv = vim.uv or vim.loop

local function parallelism()
    if uv and uv.available_parallelism then
        return math.max(2, uv.available_parallelism())
    end
    return 4
end

local function notify(msg, level)
    vim.notify(msg, level or vim.log.levels.INFO, { title = "C++ Modules" })
end

local function project_root()
    return vim.fn.getcwd()
end

local function path_exists(path)
    return uv.fs_stat(path) ~= nil
end

local function is_symlink(path)
    local s = uv.fs_lstat(path)
    return s ~= nil and s.type == "link"
end

-- ---------------------------------------------------------------------------
-- clangd LSP config
-- ---------------------------------------------------------------------------

local function build_capabilities()
    local caps = vim.lsp.protocol.make_client_capabilities()
    local ok, blink = pcall(require, "blink.cmp")
    if ok and type(blink.get_lsp_capabilities) == "function" then
        caps = blink.get_lsp_capabilities(caps)
    end
    return caps
end

local function resolve_root(bufnr)
    local markers = {
        ".clangd",
        "compile_commands.json",
        "build/compile_commands.json",
        "CMakeLists.txt",
        ".git",
    }
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    local start = bufname ~= "" and bufname or vim.fn.getcwd()
    local hit = vim.fs.find(markers, { upward = true, path = start })[1]
    if hit then
        return vim.fs.dirname(hit)
    end
    return vim.fn.getcwd()
end

local function setup_clangd()
    vim.lsp.config("clangd", {
        cmd = {
            "clangd",
            "--background-index",
            "--clang-tidy",
            "--completion-style=detailed",
            "--function-arg-placeholders",
            "--header-insertion=never",
            "--pch-storage=memory",
            "--all-scopes-completion",
            "-j=" .. tostring(parallelism()),
        },
        filetypes = { "c", "cpp", "objc", "objcpp", "cuda" },
        root_dir = function(bufnr, cb)
            cb(resolve_root(bufnr))
        end,
        capabilities = build_capabilities(),
    })
    vim.lsp.enable("clangd")
end

local function restart_clangd()
    local clients = vim.lsp.get_clients({ name = "clangd" })
    for _, client in ipairs(clients) do
        vim.lsp.stop_client(client.id, true)
    end
    vim.defer_fn(function()
        for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_loaded(bufnr) then
                local ft = vim.bo[bufnr].filetype
                if ft == "c" or ft == "cpp" or ft == "objc" or ft == "objcpp" or ft == "cuda" then
                    vim.api.nvim_exec_autocmds("FileType", { buffer = bufnr })
                end
            end
        end
    end, 200)
end

-- ---------------------------------------------------------------------------
-- :CxxModulesConfigure
-- ---------------------------------------------------------------------------

local function symlink_compile_db(root)
    local link = root .. "/compile_commands.json"
    local target = "build/compile_commands.json"
    local absolute_target = root .. "/" .. target

    if not path_exists(absolute_target) then
        return false, "build/compile_commands.json was not produced by cmake"
    end

    if path_exists(link) then
        if is_symlink(link) then
            local current = uv.fs_readlink(link)
            if current == target or current == absolute_target then
                return true, "symlink already present"
            end
            uv.fs_unlink(link)
        else
            return false, "a real compile_commands.json exists at project root; leaving it alone"
        end
    end

    local ok, err = uv.fs_symlink(target, link)
    if not ok then
        return false, "symlink failed: " .. tostring(err)
    end
    return true, "symlinked compile_commands.json → build/compile_commands.json"
end

local function cxx_modules_configure()
    local root = project_root()
    local cmd = {
        "cmake",
        "-S", ".",
        "-B", "build",
        "-G", "Ninja",
        "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON",
        "-DCMAKE_CXX_STANDARD=23",
        "-DCMAKE_CXX_STANDARD_REQUIRED=ON",
        "-DCMAKE_CXX_SCAN_FOR_MODULES=ON",
    }

    notify("running: " .. table.concat(cmd, " "))

    vim.system(cmd, { cwd = root, text = true }, function(obj)
        vim.schedule(function()
            if obj.code ~= 0 then
                local stderr = obj.stderr and obj.stderr ~= "" and obj.stderr or obj.stdout or "(no output)"
                notify("cmake configure failed (exit " .. tostring(obj.code) .. "):\n" .. stderr, vim.log.levels.ERROR)
                return
            end

            local ok, msg = symlink_compile_db(root)
            if not ok then
                notify("configure succeeded, but: " .. msg, vim.log.levels.WARN)
                return
            end

            restart_clangd()
            notify("configure OK — " .. msg .. "; clangd restarting.")
        end)
    end)
end

-- ---------------------------------------------------------------------------
-- :CxxModulesInitClangd
-- ---------------------------------------------------------------------------

local CLANGD_TEMPLATE = [[
CompileFlags:
  Add: [-std=c++23, -Wall, -Wextra]
Index:
  Background: Build
Diagnostics:
  UnusedIncludes: None
]]

local function cxx_modules_init_clangd()
    local path = project_root() .. "/.clangd"
    -- "wx" = create exclusive; fails with EEXIST if file is present.
    local fd, err = uv.fs_open(path, "wx", tonumber("644", 8))
    if not fd then
        notify(".clangd already exists at " .. path .. " — leaving untouched (" .. tostring(err) .. ")", vim.log.levels.WARN)
        return
    end
    uv.fs_write(fd, CLANGD_TEMPLATE, 0)
    uv.fs_close(fd)
    notify("wrote " .. path)
end

-- ---------------------------------------------------------------------------
-- lazy.nvim plugin spec
-- ---------------------------------------------------------------------------

return {
    dir = vim.fn.stdpath("config"),
    name = "cxx-modules",
    dependencies = { "neovim/nvim-lspconfig" },
    ft = { "c", "cpp", "objc", "objcpp", "cuda" },
    cmd = { "CxxModulesConfigure", "CxxModulesInitClangd" },

    init = function()
        vim.filetype.add({
            extension = {
                cppm = "cpp", -- Clang / standard module interface
                ixx = "cpp",  -- MSVC module interface
                mpp = "cpp",
                ccm = "cpp",
            },
        })
    end,

    config = function()
        setup_clangd()

        vim.api.nvim_create_user_command("CxxModulesConfigure", cxx_modules_configure, {
            desc = "Configure CMake with C++23 module scanning and refresh clangd",
        })
        vim.api.nvim_create_user_command("CxxModulesInitClangd", cxx_modules_init_clangd, {
            desc = "Write a default .clangd config at the project root",
        })
    end,
}
