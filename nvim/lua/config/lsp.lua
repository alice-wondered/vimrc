local vim = vim

-- Installing LSPs with Mason
require("mason").setup()
require("mason-lspconfig").setup({
    ensure_installed = {
        "gopls", "html", "htmx", "jdtls", "basedpyright", "tailwindcss",
        "vimls", "lua_ls", "rust_analyzer", "ts_ls", "jsonls", "cssls"
    },
    handlers = {
        function(server_name)
            require('lspconfig')[server_name].setup({})
        end
    }
})

local cap = require("cmp_nvim_lsp").default_capabilities()
local lspconfig = require('lspconfig')
local servers = {
    'rust_analyzer', 'gopls', 'html', 'htmx', 'tailwindcss',
    'jdtls', 'basedpyright', 'vimls', 'lua_ls', 'ts_ls', 'jsonls', 'cssls'
}

-- Keymaps for LSP actions
local on_attach = function(client, bufnr)
    -- Enable completion (already handled by nvim-cmp but good to be explicit)
    -- vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')

    local opts = { noremap = true, silent = true }
    local set_lsp_keymap = function(mode, lhs, rhs, desc)
        -- DEBUG: Print information about the keymap being set
        local rhs_type = type(rhs)
        print(string.format("LSP Keymap Debug: Trying to set '%s'. RHS type is '%s'.", lhs, rhs_type))

        if rhs_type == 'function' then
            vim.keymap.set(mode, lhs, rhs, vim.tbl_extend('force', opts, { desc = desc }))
        else
            -- DEBUG: Explicitly print when a keymap is skipped
            print(string.format("LSP Keymap Debug: SKIPPED setting '%s' because RHS is not a function.", lhs))
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

    -- -- Enable completion on `.` (or other trigger characters)
    -- if client.server_capabilities.completionProvider and client.server_capabilities.completionProvider.triggerCharacters then
    --     vim.api.nvim_create_autocmd("TextChangedI", {
    --         buffer = bufnr,
    --         callback = function()
    --             local line = vim.api.nvim_get_current_line()
    --             local col = vim.api.nvim_win_get_cursor(0)[2]
    --             local char = line:sub(col, col)
    --             if vim.tbl_contains(client.server_capabilities.completionProvider.triggerCharacters, char) then
    --                 vim.defer_fn(function()
    --                     vim.lsp.buf.completion()
    --                 end, 100) -- Small delay to allow character to be inserted
    --             end
    --         end,
    --         desc = "Trigger completion on special characters"
    --     })
    -- end

    -- Enable "Format on Save" (optional)
    vim.api.nvim_create_autocmd("BufWritePre", {
        buffer = bufnr,
        callback = function()
            if client.supports_method("textDocument/formatting") then
                vim.lsp.buf.format({ async = true })
            end
        end,
        desc = "Format on save"
    })
end

-- Setup LSP servers with on_attach
for _, lsp in ipairs(servers) do
    lspconfig[lsp].setup {
        capabilities = cap,
        on_attach = on_attach, -- Attach common keymaps and autocommands
    }
end

-- Tailwind-Tools integration for LSP completion kind
require("tailwind-tools").setup({})

vim.diagnostic.config({
    virtual_text = { severity = { min = vim.diagnostic.severity.ERROR } },
    signs = true,
    underline = true,
    update_in_insert = false,
    severity_sort = false,
})
