local vim = vim

vim.opt.guicursor='a:blinkon100'
vim.opt.hidden = true
vim.opt.showmatch = true
vim.opt.hlsearch = true
vim.opt.incsearch = true

vim.opt.tabstop=4 
vim.opt.softtabstop=4 
vim.opt.expandtab = true
vim.opt.shiftwidth=4 
vim.opt.autoindent = true 

vim.opt.number = true
vim.opt.relativenumber = true

vim.opt.scrolloff=8
vim.opt.mouse='a' 

vim.opt.ttyfast = true

local Plug = vim.fn['plug#']
vim.call('plug#begin')
Plug('nvim-lua/plenary.nvim') -- This is just a library of utility functions

-- A bunch of stuff that can highlight pairs, tab out of quotes, close html
-- tags, etc
Plug('alvan/vim-closetag')
Plug('abecodes/tabout.nvim')
Plug('windwp/nvim-autopairs')
Plug('numToStr/Comment.nvim')
Plug('onsails/lspkind.nvim')

-- If you're reading this wondering why some search features aren't working
-- it's probably because you need to install ripgrep :)
Plug('nvim-telescope/telescope-fzf-native.nvim', { ['do'] = 'cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release && cmake --install build --prefix build' })
Plug('nvim-telescope/telescope.nvim', { ['tag'] = '0.1.8' })

-- Autocomplete
Plug('neovim/nvim-lspconfig')
Plug('williamboman/mason.nvim')
Plug('williamboman/mason-lspconfig.nvim')
Plug('hrsh7th/cmp-nvim-lsp')
Plug('hrsh7th/cmp-buffer')
Plug('hrsh7th/cmp-path')
Plug('hrsh7th/cmp-cmdline')
Plug('hrsh7th/nvim-cmp')

Plug('nvim-treesitter/nvim-treesitter', {['do'] = ':TSUpdate'})

-- Snippets
Plug('L3MON4D3/LuaSnip', {['tag'] = 'v2.*', ['do'] = 'make install_jsregexp'})
Plug('rafamadriz/friendly-snippets')
Plug('saadparwaiz1/cmp_luasnip')


-- bottom bar and icons
Plug('nvim-lualine/lualine.nvim')
Plug('nvim-tree/nvim-web-devicons')

Plug('kdheepak/lazygit.nvim')
Plug('rhysd/git-messenger.vim')

Plug('catppuccin/nvim', { ['as'] = 'catppuccin' })
Plug('luckasRanarison/tailwind-tools.nvim')
vim.call('plug#end')

require("catppuccin").setup({
    term_colors = true, -- sets terminal colors (e.g. `g:terminal_color_0`)
    dim_inactive = {
        enabled = true, -- dims the background color of inactive window
        shade = "dark",
        percentage = 0.15, -- percentage of the shade to apply to the inactive window
    },
    no_italic = false, -- Force no italic
    no_bold = false, -- Force no bold
    no_underline = false, -- Force no underline
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

-- Configuring lualine options
require('lualine').setup {
  options = {
    icons_enabled = true,
    theme = "catppuccin",
    component_separators = { left = '', right = ''},
    section_separators = { left = '', right = ''},
    disabled_filetypes = {
      statusline = {},
      winbar = {},
    },
    ignore_focus = {},
    always_divide_middle = true,
    globalstatus = false,
    refresh = {
      statusline = 1000,
      tabline = 1000,
      winbar = 1000,
    }
  },
  sections = {
    lualine_a = {'mode'},
    lualine_b = {'branch', 'diff', 'diagnostics'},
    lualine_c = {'filename'},
    lualine_x = {'encoding', 'fileformat', 'filetype'},
    lualine_y = {'progress'},
    lualine_z = {'location'}
  },
  inactive_sections = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = {'filename'},
    lualine_x = {'location'},
    lualine_y = {},
    lualine_z = {}
  },
  tabline = {
    lualine_c = {"buffers"}
  },
  winbar = {},
  inactive_winbar = {},
  extensions = {}
}

-- Configuring options for Tree-Sitter
vim.highlight.priorities.semantic_tokens = 95
require('nvim-treesitter.configs').setup {
  -- A list of parser names, or "all" (the five listed parsers should always be installed)
  ensure_installed = { "c", "rust", "lua", "vim", "vimdoc", "query", "go", "python", "java", "html", "css", "javascript", "json" },

  -- Install parsers synchronously (only applied to `ensure_installed`)
  sync_install = false,

  -- Automatically install missing parsers when entering buffer
  -- Recommendation: set to false if you don't have `tree-sitter` CLI installed locally
  auto_install = true,

  -- List of parsers to ignore installing (or "all")
  -- ignore_install = { "javascript" },

  ---- If you need to change the installation directory of the parsers (see -> Advanced Setup)
  -- parser_install_dir = "/some/path/to/store/parsers", -- Remember to run vim.opt.runtimepath:append("/some/path/to/store/parsers")!

  highlight = {
    enable = true,

    -- NOTE: these are the names of the parsers and not the filetype. (for example if you want to
    -- disable highlighting for the `tex` filetype, you need to include `latex` in this list as this is
    -- the name of the parser)
    -- list of language that will be disabled
    -- disable = { "c", "rust" },
    -- Or use a function for more flexibility, e.g. to disable slow treesitter highlight for large files
    disable = function(lang, buf)
        local max_filesize = 100 * 1024 -- 100 KB
        local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
        if ok and stats and stats.size > max_filesize then
            return true
        end
    end,

    -- Setting this to true will run `:h syntax` and tree-sitter at the same time.
    -- Set this to `true` if you depend on 'syntax' being enabled (like for indentation).
    -- Using this option may slow down your editor, and you may see some duplicate highlights.
    -- Instead of true it can also be a list of languages
    additional_vim_regex_highlighting = false,
  },
}


--- Telescope configuration stuff
local builtin = require('telescope.builtin')
vim.g.mapleader = " "
vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})
vim.keymap.set('n', '<leader>gf', builtin.git_files, {})
vim.keymap.set('n', '<leader>fb', builtin.buffers, {})
vim.keymap.set('n', '<leader>fh', builtin.help_tags, {})

--- Turn on lualine and add lazygit to telescope
require('telescope').load_extension('lazygit')

--- Installing LSPs with Mason
require("mason").setup()
require("mason-lspconfig").setup({
    ensure_installed = { "gopls", "html", "htmx", "jdtls", "basedpyright", "tailwindcss", "vimls", "lua_ls", "rust_analyzer" },
    handlers = {
        -- this first function is the "default handler"
        -- it applies to every language server without a "custom handler"
        function(server_name)
            require('lspconfig')[server_name].setup({})
        end
    }
})

local cap = require("cmp_nvim_lsp").default_capabilities()
local lspconfig = require('lspconfig')
local servers = { 'rust_analyzer', 'gopls', 'html', 'htmx', 'tailwindcss', 'jdtls', 'basedpyright', 'vimls', 'lua_ls'}
for _, lsp in ipairs(servers) do 
    lspconfig[lsp].setup {
        capabilities = cap
    }
end

--- CMP plugin for autocompletion
require("nvim-autopairs").setup {}
local cmp_autopairs = require('nvim-autopairs.completion.cmp')
local cmp = require('cmp')

--- adds the pictograms to the cmp auto complete window
local lspkind = require('lspkind')

cmp.event:on(
  'confirm_done',
  cmp_autopairs.on_confirm_done()
)

cmp.setup({
  sources = cmp.config.sources({
    {name = 'nvim_lsp'},
    { name = 'luasnip' },
  }),
  mapping = {
    ['<CR>'] = cmp.mapping.confirm({
        behavior = cmp.ConfirmBehavior.Replace,
        select = true
    }),
    ["<Tab>"] = function(fallback)
        if cmp.visible() then
            cmp.select_next_item({behavior = 'insert'})
        else
            fallback()
        end
    end,
    ["<S-Tab>"] = function(fallback)
        if cmp.visible() then
            cmp.select_prev_item({behavior = 'insert'})
        else
            fallback()
        end
    end,
    ['<C-e>'] = cmp.mapping.abort(),
    ['<C-p>'] = cmp.mapping(function()
      if cmp.visible() then
        cmp.select_prev_item({behavior = 'insert'})
      else
        cmp.complete()
      end
    end),
    ['<C-n>'] = cmp.mapping(function()
      if cmp.visible() then
        cmp.select_next_item({behavior = 'insert'})
      else
        cmp.complete()
      end
    end),
  },
  snippet = {
    expand = function(args)
      require('luasnip').lsp_expand(args.body)
    end,
  },
  completion = { completeopt = "noselect" },
  preselect = cmp.PreselectMode.None,
  formatting = {
      format = lspkind.cmp_format({
        before = require("tailwind-tools.cmp").lspkind_format,
        mode = 'symbol',
        maxwidth = 50,
        ellipsis_char = '...',
        show_labelDetails = true,
        before = function (entry, vim_item)
            return vim_item
        end
    })
 },
})


--- this block is really meant to address tab conflicts but cmp already has a handler for it
require('tabout').setup({})

require("Comment").setup()

require("tailwind-tools").setup({})

--- QOL keymaps
vim.keymap.set("n", "<C-d>", "<C-d>zz", {desc = "Center cursor after moving down half-page"})
vim.keymap.set("n", "<C-u>", "<C-u>zz", {desc = "Center cursor after moving up half-page"})
vim.diagnostic.config({
  virtual_text = true,
  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = false,
})


