local vim = vim

-- Installing LSPs with Mason
require("mason").setup()

local cap = require("cmp_nvim_lsp").default_capabilities()
local capabilities = vim.lsp.protocol.make_client_capabilities()
for k, v in pairs(cap) do
    capabilities[k] = v
end

capabilities.textDocument.codeAction = {
    dynamicRegistration = true,
    codeActionLiteralSupport = {
        codeActionKind = {
            valueSet = {
                "",
            },
        },
    },
}

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

    -- replaced with conform.nvim
    -- Enable "Format on Save" (optional)
    -- In lua/config/lsp.lua, inside your on_attach function
    -- vim.api.nvim_create_autocmd("BufWritePre", {
    --     group = vim.api.nvim_create_augroup("LspFormatOnSave", { clear = true }),
    --     buffer = bufnr,
    --     callback = function()
    --         -- This 'if' check is key: it verifies the attached LSP client supports formatting
    --         if client.supports_method("textDocument/formatting") then
    --             vim.lsp.buf.format({ bufnr = bufnr })
    --         end
    --     end,
    -- })
end

local lspconfig = require('lspconfig')
local default_servers = { 'biome', 'rust_analyzer', 'gopls', 'html', 'tailwindcss', 'basedpyright', 'vimls', 'lua_ls',
    'marksman', 'cssls', 'jsonls' }

-- Setup LSP servers with on_attach
for _, lsp in ipairs(default_servers) do
    lspconfig[lsp].setup {
        capabilities = capabilities,
        on_attach = on_attach, -- Attach common keymaps and autocommands
    }
end

-- Explicitly setup customized LSP servers with their specific configs
-- 1. ts_ls (for TypeScript type-checking, completions, etc. - RENAMED FROM tsserver)
lspconfig.ts_ls.setup {
    root_markers = { '.git', 'tsconfig.json', 'jsconfig.json', 'package.json', },
    settings = {
        typescript = {
            format = { enabled = false },
        },
        javascript = {
            format = { enabled = false },
        },
    },
    on_attach = function(client, bufnr)
        on_attach(client, bufnr)
        client.server_capabilities.documentFormattingProvider = false
        client.server_capabilities.documentRangeFormattingProvider = false
    end,
    capabilities = capabilities,
}

-- Tailwind-Tools integration for LSP completion kind
require("tailwind-tools").setup({})

vim.diagnostic.config({
    virtual_text = { severity = { min = vim.diagnostic.severity.ERROR } },
    signs = true,
    underline = true,
    update_in_insert = true,
    severity_sort = false,
})
