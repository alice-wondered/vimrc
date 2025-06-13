-- lua/config/options.lua
local vim = vim

-- General Vim options
vim.opt.guicursor = 'n-v-c:block-blinkon500,i:ver25-blinkon500'
vim.opt.hidden = true
vim.opt.showmatch = true
vim.opt.hlsearch = true
vim.opt.incsearch = true

-- Indentation options
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.autoindent = true

-- Line numbering
vim.opt.number = true
vim.opt.relativenumber = true

-- Scrolling and mouse
vim.opt.scrolloff = 8
vim.opt.mouse = 'a'

-- Performance
vim.opt.ttyfast = true

-- General UI settings
vim.opt.termguicolors = true -- Enable true colors
vim.opt.timeoutlen = 500     -- Time to wait for a mapped sequence to complete (ms)
vim.opt.undofile = true      -- Persistent undo
vim.opt.updatetime = 300     -- Faster completion and diagnostics update
vim.opt.signcolumn = 'yes'   -- Always show the sign column to prevent text shifting
vim.opt.cmdheight = 1        -- Hide the command bar after every command
vim.opt.laststatus = 3       -- Always show statusline
vim.opt.wrap = false         -- Disable line wrapping
