local vim = vim

-- Installing LSPs with Mason
require("mason").setup()

-- Keymaps for LSP actions
local on_attach = function(client, bufnr)
    -- Enable completion (already handled by nvim-cmp but good to be explicit)
    -- vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')

    local opts = { noremap = true, silent = true }
    local set_lsp_keymap = function(mode, lhs, rhs, desc)
        -- DEBUG: Print information about the keymap being set
        local rhs_type = type(rhs)
        -- print(string.format("LSP Keymap Debug: Trying to set '%s'. RHS type is '%s'.", lhs, rhs_type))

        if rhs_type == 'function' then
            vim.keymap.set(mode, lhs, rhs, vim.tbl_extend('force', opts, { desc = desc }))
        else
            -- DEBUG: Explicitly print when a keymap is skipped
            -- print(string.format("LSP Keymap Debug: SKIPPED setting '%s' because RHS is not a function.", lhs))
        end
    end

    set_lsp_keymap('n', 'gd', vim.lsp.buf.definition, "Go to Definition")
    set_lsp_keymap('n', 'gD', vim.lsp.buf.declaration, "Go to Declaration")
    set_lsp_keymap('n', 'gr', vim.lsp.buf.references, "Show References")
    set_lsp_keymap('n', 'gi', vim.lsp.buf.implementation, "Go to Implementation")
    set_lsp_keymap('n', 'gt', vim.lsp.buf.type_definition, "Go to Type Definition")
    set_lsp_keymap('n', 'K', vim.lsp.buf.hover, "Show documentation on hover")
    set_lsp_keymap('n', '<C-k>', vim.lsp.buf.signature_help, "Signature Help")

    set_lsp_keymap('n', '[d', vim.diagnostic.goto_prev, "Go to previous diagnostic")
    set_lsp_keymap('n', ']d', vim.diagnostic.goto_next, "Go to next diagnostic")
    set_lsp_keymap('n', '<leader>q', vim.diagnostic.set_loclist, "Show diagnostics in quickfix list")

    if client.server_capabilities.renameProvider then
        set_lsp_keymap('n', '<leader>rn', vim.lsp.buf.rename, "Rename")
    end

    if client.server_capabilities.codeActionProvider then
        set_lsp_keymap('n', '<leader>ca', vim.lsp.buf.code_action, "Code Action")
    end

    if client.server_capabilities.documentFormattingProvider then
        set_lsp_keymap('n', '<leader>f', vim.lsp.buf.format, "Format buffer")
    end

    -- Auto-commands for LSP
    if client.server_capabilities.document_highlight then
        vim.api.nvim_create_autocmd('CursorHold', {
            buffer = bufnr,
            callback = vim.lsp.buf.document_highlight,
            desc = "Document Highlight"
        })
        vim.api.nvim_create_autocmd('CursorMoved', {
            buffer = bufnr,
            callback = vim.lsp.buf.clear_references,
            desc = "Clear References"
        })
    end
end

local MiniDiff = require("mini.diff")
local range_ignore_filetypes = { "lua" }
local diff_format = function()
    local data = MiniDiff.get_buf_data()
    if not data or not data.hunks then
        vim.notify("No hunks in this buffer")
        return
    end
    local format = require("conform").format
    -- stylua range format mass up indent, so use full format for now
    if vim.tbl_contains(range_ignore_filetypes, vim.bo.filetype) then
        format({ lsp_fallback = true, timeout_ms = 500 })
        return
    end
    local ranges = {}
    for _, hunk in pairs(data.hunks) do
        if hunk.type ~= "delete" then
            -- always insert to index 1 so format below could start from last hunk, which this sort didn't mess up range
            table.insert(ranges, 1, {
                start = { hunk.buf_start, 0 },
                ["end"] = { hunk.buf_start + hunk.buf_count, 0 },
            })
        end
    end
    for _, range in pairs(ranges) do
        format({ lsp_fallback = true, timeout_ms = 500, range = range })
    end
end

local conform = require("conform")
conform.setup({
    formatters_by_ft = {
        lua = { "stylua" },
        -- Conform will run multiple formatters sequentially
        python = { "isort", "black" },
        -- You can customize some of the format options for the filetype (:help conform.format)
        rust = { "rustfmt", lsp_format = "fallback" },
        go = { "goimports", "gofmt", lsp_format = "fallback" },
        typescript = { "prettierd", "prettier", "biome" },
        typescriptreact = { "prettierd", "prettier", "biome" },
        javascript = { "prettierd", "prettier", "biome" },
        terraform = { "terraform_fmt" },
    },
    format_on_save = function(bufnr)
        if vim.g.disable_autoformat then
            return false
        end
        -- Check buffer-specific disable flag
        if vim.b[bufnr].disable_autoformat then
            return false
        end
        diff_format()
    end,
    on_attach = function(client, bufnr)
        on_attach(client, bufnr)
        client.server_capabilities.documentFormattingProvider = false
        client.server_capabilities.documentRangeFormattingProvider = false
    end,
    capabilities = capabilities,
})

local default_servers = { 'biome', 'rust_analyzer', 'gopls', 'html', 'basedpyright', 'vimls', 'lua_ls',
    'marksman', 'jsonls', 'mdx_analyzer', 'terraformls', 'vtsls', 'tailwindcss' }

-- vim.lsp.config('tsgo', {
--     cmd = { 'tsgo', '--lsp', '--stdio' },
--     filetypes = {
--         'javascript',
--         'javascriptreact',
--         'typescript',
--         'typescriptreact',
--         'javascript.jsx',
--         'typescript.tsx',
--     },
--     root_markers = {
--         '.git',
--         'tsconfig.json',
--         'package.json',
--         'tsconfig.base.json',
--     },
--     -- this probably doesn't work but it's worth a shot 
--     settings = {
--         typescript = {
--             updateImportsOnFileMove = { enabled = "always" },
--             tsserver = {
--                 maxTsServerMemory = 8192,
--                 experimental = {
--                     enableProjectDiagnostics = true,
--                 },
--             },
--             preferences = {
--                 includePackageJsonAutoImports = "on",
--                 includeCompletionsForModuleExports = true,
--                 includeCompletionsForImportStatements = true,
--             },
--         },
--     },
-- })

vim.lsp.config('vtsls', {
    settings = {
        vtsls = {
            autoUseWorkspaceTsdk = true,
            experimental = {
                completion = {
                    enableServerSideFuzzyMatch = true,
                    entriesLimit = 50,
                },
            },
        },
        typescript = {
            updateImportsOnFileMove = { enabled = "always" },
            tsserver = {
                maxTsServerMemory = 8192,
                experimental = {
                    enableProjectDiagnostics = true,
                },
            },
            preferences = {
                includePackageJsonAutoImports = "on",
                includeCompletionsForModuleExports = true,
                includeCompletionsForImportStatements = true,
            },
        },
    },
})


-- Setup LSP servers with defaults from lspconfig
for _, lsp in ipairs(default_servers) do
    vim.lsp.enable(lsp)
end

-- Attach common keymaps and other settings 
vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("my.lsp", {}),
    callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        local bufnr = args.buf
        on_attach(client, bufnr)
    end,
})

vim.diagnostic.config({
    virtual_text = { severity = { min = vim.diagnostic.severity.ERROR } },
    signs = true,
    underline = true,
    update_in_insert = true,
    severity_sort = false,
})

require("typescript-tools").setup {
  on_attach = on_attach,
  settings = {
    -- spawn additional tsserver instance to calculate diagnostics on it
    separate_diagnostic_server = true,
    -- "change"|"insert_leave" determine when the client asks the server about diagnostic
    publish_diagnostic_on = "insert_leave",
    -- array of strings("fix_all"|"add_missing_imports"|"remove_unused"|
    -- "remove_unused_imports"|"organize_imports") -- or string "all"
    -- to include all supported code actions
    -- specify commands exposed as code_actions
    expose_as_code_action = {},
    -- string|nil - specify a custom path to `tsserver.js` file, if this is nil or file under path
    -- not exists then standard path resolution strategy is applied
    tsserver_path = nil,
    -- specify a list of plugins to load by tsserver, e.g., for support `styled-components`
    -- (see 💅 `styled-components` support section)
    tsserver_plugins = {},
    -- this value is passed to: https://nodejs.org/api/cli.html#--max-old-space-sizesize-in-megabytes
    -- memory limit in megabytes or "auto"(basically no limit)
    tsserver_max_memory = "auto",
    -- described below
    tsserver_format_options = {},
    tsserver_file_preferences = {},
    -- locale of all tsserver messages, supported locales you can find here:
    -- https://github.com/microsoft/TypeScript/blob/3c221fc086be52b19801f6e8d82596d04607ede6/src/compiler/utilitiesPublic.ts#L620
    tsserver_locale = "en",
    -- mirror of VSCode's `typescript.suggest.completeFunctionCalls`
    complete_function_calls = false,
    include_completions_with_insert_text = true,
    -- CodeLens
    -- WARNING: Experimental feature also in VSCode, because it might hit performance of server.
    -- possible values: ("off"|"all"|"implementations_only"|"references_only")
    code_lens = "off",
    -- by default code lenses are displayed on all referencable values and for some of you it can
    -- be too much this option reduce count of them by removing member references from lenses
    disable_member_code_lens = true,
    -- JSXCloseTag
    -- WARNING: it is disabled by default (maybe you configuration or distro already uses nvim-ts-autotag,
    -- that maybe have a conflict if enable this feature. )
    jsx_close_tag = {
        enable = false,
        filetypes = { "javascriptreact", "typescriptreact" },
    }
  },
}
