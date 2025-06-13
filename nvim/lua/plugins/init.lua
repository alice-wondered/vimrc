return {
    'nvim-lua/plenary.nvim',
    {
        'echasnovski/mini.nvim',
        config = function()
            require('mini.comment').setup()
            require('mini.pairs').setup()
            require('mini.surround').setup()
            require('mini.ai').setup()
            require('mini.snippets').setup()
        end,
    },
    'onsails/lspkind.nvim', -- For nvim-cmp icons
    -- Fuzzy Finder (Telescope)
    {
        'nvim-telescope/telescope-fzf-native.nvim',
        build =
        'cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release && cmake --install build --prefix build',
    },
    {
        'nvim-telescope/telescope.nvim',
        tag = '0.1.8',
        dependencies = { 'nvim-lua/plenary.nvim' },
    },

    -- Autocomplete (nvim-cmp and LSP setup)
    'neovim/nvim-lspconfig',
    'williamboman/mason.nvim',
    'williamboman/mason-lspconfig.nvim',
    'hrsh7th/cmp-nvim-lsp',
    'hrsh7th/cmp-buffer',
    'hrsh7th/cmp-path',
    'hrsh7th/cmp-cmdline',

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
}
