local augroup = vim.api.nvim_create_augroup("LspFormatting", {})
return {
    'nvim-lua/plenary.nvim',
    {
        'echasnovski/mini.nvim',
        config = function()
            require('mini.statusline').setup()
            require('mini.tabline').setup()
            require('mini.comment').setup()
            require('mini.pairs').setup()
            require('mini.surround').setup()
            require('mini.ai').setup()
            require('mini.snippets').setup()
            require('mini.icons').setup()
        end,
    },
    'onsails/lspkind.nvim', -- For nvim-cmp icons
    {
        "ibhagwan/fzf-lua",
        dependencies = { "echasnovski/mini.icons" },
        opts = {},
        config = function()
            require("fzf-lua").setup {
                defaults = {
                    file_icons = "mini",
                }

            }
        end,
    },
    {
        "ThePrimeagen/harpoon",
        branch = "harpoon2",
        dependencies = { "nvim-lua/plenary.nvim" },
    },
    -- Autocomplete (nvim-cmp and LSP setup)
    'neovim/nvim-lspconfig',
    'williamboman/mason.nvim',
    'hrsh7th/cmp-nvim-lsp',
    'hrsh7th/cmp-buffer',
    'hrsh7th/cmp-path',
    'hrsh7th/cmp-cmdline',
    --- we specifically use this for prettier right now, everything else is LSP based
    {
        'nvimtools/none-ls.nvim',
        dependencies = { 'nvim-lua/plenary.nvim' },
        config = function()
            local null_ls = require('null-ls')
            null_ls.setup({
                on_attach = function(client, bufnr)
                    if client.supports_method('textDocument/formatting') then
                        vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })
                        vim.api.nvim_create_autocmd('BufWritePre', {
                            group = augroup,
                            buffer = bufnr,
                            callback = function()
                                vim.lsp.buf.format({
                                    async = false,
                                    bufnr = bufnr,
                                    filter = function(client)
                                        return client.name == 'null-ls'
                                    end
                                })
                            end,
                        })
                    end
                end,
            })
        end,
    },
    {
        'MunifTanjim/prettier.nvim',
        dependencies = { 'neovim/nvim-lspconfig', 'nvimtools/none-ls.nvim' },
        config = function()
            local prettier = require("prettier")
            prettier.setup({
                ["null-ls"] = {
                    condition = function()
                        return prettier.config_exists({
                            -- if `false`, skips checking `package.json` for `"prettier"` key
                            check_package_json = true,
                        })
                    end,
                    runtime_condition = function(params)
                        -- return false to skip running prettier
                        return true
                    end,
                    timeout = 5000,
                }
            })
        end,

    },
    -- Treesitter
    {
        'nvim-treesitter/nvim-treesitter',
        build = ':TSUpdate',
        dependencies = { 'nvim-treesitter/nvim-treesitter-textobjects' },
        config = function()
            require('nvim-treesitter.configs').setup {
                ensure_installed = {
                    "c", "rust", "lua", "vim", "vimdoc", "query", "go", "python", "java", "html", "css",
                    "javascript", "json", "typescript", "tsx", "bash", "markdown", "markdown_inline"
                },
                sync_install = false,
                auto_install = true,
                highlight = {
                    enable = true,
                    disable = function(lang, buf)
                        local max_filesize = 100 * 1024 -- 100 KB
                        local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
                        if ok and stats and stats.size > max_filesize then
                            return true
                        end
                    end,
                    additional_vim_regex_highlighting = false,
                },
                -- New: configure textobjects
                textobjects = {
                    select = {
                        enable = true,
                        -- You can extend this with more mappings
                        -- `af` (around function), `if` (inside function), etc.
                        -- Check :h nvim-treesitter-textobjects-select
                        lookahead = true, -- Story about whether to look ahead for the next node
                        keymaps = {
                            -- These are examples, choose your own!
                            ['af'] = '@function.outer',
                            ['if'] = '@function.inner',
                            ['ac'] = '@class.outer',
                            ['ic'] = '@class.inner',
                            ['aP'] = '@parameter.outer',
                            ['iP'] = '@parameter.inner',
                            ['aa'] = '@arglist.outer',
                            ['ia'] = '@arglist.inner',
                        },
                    },
                    swap = {
                        enable = true,
                        swap_next = {
                            ['<leader>an'] = '@parameter.inner',
                        },
                        swap_previous = {
                            ['<leader>ap'] = '@parameter.inner',
                        },
                    },
                    move = {
                        enable = true,
                        set_jumps = true, -- whether to set jumps in the jumplist
                        goto_next_start = {
                            [']]'] = '@function.outer',
                            [']['] = '@class.outer',
                            [']P'] = '@parameter.outer',
                            [']p'] = '@parameter.inner',
                        },
                        goto_next_end = {
                            ['M]]'] = '@function.outer',
                            ['M]['] = '@class.outer',
                        },
                        goto_previous_start = {
                            ['[['] = '@function.outer',
                            ['[]'] = '@class.outer',
                        },
                        goto_previous_end = {
                            ['M[['] = '@function.outer',
                            ['M[]'] = '@class.outer',
                        },
                    },
                },
            }
        end,
    },

    -- Icons
    'nvim-tree/nvim-web-devicons',

    -- Git related
    'kdheepak/lazygit.nvim',
    'rhysd/git-messenger.vim',

    -- Colorscheme and specific language tools
    {
        'catppuccin/nvim',
        as = 'catppuccin',
        config = function()
            require("catppuccin").setup({
                term_colors = true,
                dim_inactive = {
                    enabled = true,
                    shade = "dark",
                    percentage = 0.15,
                },
                no_italic = false,
                no_bold = false,
                no_underline = false,
                flavour = "mocha",
                transparent_background = true,
                default_integrations = true,
                integrations = {
                    native_lsp = {
                        enabled = true,
                        virtual_text = {
                            errors = { "italic" },
                            hints = { "italic" },
                            warnings = { "italic" },
                            information = { "italic" },
                            ok = { "italic" },
                        },
                        underlines = {
                            errors = { "underline" },
                            hints = { "underline" },
                            warnings = { "underline" },
                            information = { "underline" },
                            ok = { "underline" },
                        },
                        inlay_hints = {
                            background = true,
                        },
                    },
                    cmp = true,
                    treesitter = true,
                    mason = true,
                    telescope = {
                        enabled = true
                    },
                }
            })
            vim.cmd.colorscheme "catppuccin"
        end
    },
    'luckasRanarison/tailwind-tools.nvim',
    {
        'supermaven-inc/supermaven-nvim',
        config = function()
            require("supermaven-nvim").setup({})
        end,
    },
    -- CMP plugin for autocompletion
    {
        'hrsh7th/nvim-cmp',
        dependencies = {
            'hrsh7th/cmp-nvim-lsp',
            'hrsh7th/cmp-buffer',
            'hrsh7th/cmp-path',
            'hrsh7th/cmp-cmdline',
            -- mini.snippet acts as luasnip source
            'echasnovski/mini.nvim', -- Ensure mini.nvim is loaded for mini.snippet
            'supermaven-inc/supermaven-nvim',
        },
        config = function()
            local cmp = require('cmp')
            local lspkind = require('lspkind')
            cmp.setup({
                sources = cmp.config.sources({
                    { name = 'supermaven' },
                    { name = 'nvim_lsp' },
                    { name = 'luasnip' },
                    { name = 'buffer' },
                    { name = 'path' },
                }),
                mapping = {
                    ['<CR>'] = cmp.mapping.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = true }),
                    ["<Tab>"] = function(fallback)
                        if cmp.visible() then
                            cmp.select_next_item({ behavior = 'insert' })
                        else
                            fallback()
                        end
                    end,
                    ["<S-Tab>"] = function(fallback)
                        if cmp.visible() then
                            cmp.select_prev_item({ behavior = 'insert' })
                        else
                            fallback()
                        end
                    end,
                    ['<C-e>'] = cmp.mapping.abort(),
                    ['<C-p>'] = cmp.mapping(function()
                        if cmp.visible() then
                            cmp.select_prev_item({ behavior = 'insert' })
                        else
                            cmp.complete()
                        end
                    end),
                    ['<C-n>'] = cmp.mapping(function()
                        if cmp.visible() then
                            cmp.select_next_item({ behavior = 'insert' })
                        else
                            cmp.complete()
                        end
                    end),
                },
                -- snippet = {
                --     expand = function(args)
                --         -- mini.snippet integrates with the luasnip API
                --         require('luasnip').lsp_expand(args.body)
                --     end,
                -- },
                completion = { completeopt = "noselect" },
                preselect = cmp.PreselectMode.None,
                formatting = {
                    format = lspkind.cmp_format({
                        before = require("tailwind-tools.cmp").lspkind_format,
                        mode = 'symbol',
                        symbol_map = { Supermaven = "" },
                        maxwidth = 50,
                        ellipsis_char = '...',
                        show_labelDetails = true,
                        before = function(entry, vim_item)
                            return vim_item
                        end
                    })
                },
            })
        end,
    },
    {
        'MeanderingProgrammer/render-markdown.nvim',
        dependencies = { 'nvim-treesitter/nvim-treesitter', 'echasnovski/mini.nvim' }, -- if you use the mini.nvim suite
        ---@module 'render-markdown'
        ---@type render.md.UserConfig
        opts = {},
        config = function()
            require('render-markdown').setup({ completions = { lsp = { enabled = true } } })
        end,
    }
}
