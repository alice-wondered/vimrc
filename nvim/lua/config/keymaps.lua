-- lua/config/keymaps.lua
local vim = vim

local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- fzf-lua
local fzf = require("fzf-lua")
-- files & buffers
map('n', '<leader>ff', fzf.files, opts)
map('n', '<leader>fb', fzf.buffers, opts)
map('n', '<leader>fg', fzf.live_grep, opts)

-- git
map('n', '<leader>gf', fzf.git_files, opts)
map('n', '<leader>gc', fzf.git_commits, opts)
map('n', '<leader>gb', fzf.git_branches, opts)
map('n', '<leader>gs', fzf.git_status, opts)

-- LSP symbols
map('n', '<leader>ss', fzf.lsp_document_symbols, opts)
map('n', '<leader>sw', fzf.lsp_workspace_symbols, opts)
map('n', '<leader>gd', fzf.lsp_definitions, opts)
map('n', '<leader>gr', fzf.lsp_references, opts)

local harpoon = require("harpoon")
harpoon:setup()

vim.keymap.set("n", "<leader>a", function() harpoon:list():add() end)
vim.keymap.set("n", "<leader>l", function() harpoon.ui:toggle_quick_menu(harpoon:list()) end)

vim.keymap.set("n", "<leader>z", function() harpoon:list():select(1) end)
vim.keymap.set("n", "<leader>x", function() harpoon:list():select(2) end)
vim.keymap.set("n", "<leader>c", function() harpoon:list():select(3) end)
vim.keymap.set("n", "<leader>v", function() harpoon:list():select(4) end)

-- Toggle previous & next buffers stored within Harpoon list
vim.keymap.set("n", "<C-S-P>", function() harpoon:list():prev() end)
vim.keymap.set("n", "<C-S-N>", function() harpoon:list():next() end)

-- QOL keymaps (unchanged)
map("n", "<C-d>", "<C-d>zz", { desc = "Center cursor after moving down half-page" })
map("n", "<C-u>", "<C-u>zz", { desc = "Center cursor after moving up half-page" })

-- Window navigation
map("n", "<C-h>", "<C-w>h", opts)
map("n", "<C-j>", "<C-w>j", opts)
map("n", "<C-k>", "<C-w>k", opts)
map("n", "<C-l>", "<C-w>l", opts)

-- Buffer navigation
map("n", "<Tab>", ":bnext<CR>", { desc = "Next buffer" })
map("n", "<S-Tab>", ":bprevious<CR>", { desc = "Previous buffer" })

-- Easier saving and quitting
map("n", "<leader>w", ":w<CR>", { desc = "Save" })
map("n", "<leader>q", ":q<CR>", { desc = "Quit" })
map("n", "<leader>Q", ":qa!<CR>", { desc = "Quit all (force)" })

-- Clear search highlights
map("n", "<leader>nh", ":nohlsearch<CR>", { desc = "Clear search highlights" })

-- New: Terminal Mappings (if you use :term)
map("n", "<leader>tt", ":vsplit term://bash<CR>", { desc = "Open vertical terminal" })
map("n", "<leader>ft", ":split term://bash<CR>", { desc = "Open horizontal terminal" })

-- Insert mode navigation
map("i", "<C-h>", "<Left>", opts)
map("i", "<C-l>", "<Right>", opts)
map("i", "<C-j>", "<Down>", opts)
map("i", "<C-k>", "<Up>", opts)

-- Toggle functions
vim.api.nvim_create_user_command("FormatDisable", function(args)
  if args.bang then
    -- FormatDisable! - disable globally
    vim.g.disable_autoformat = true
  else
    -- FormatDisable - disable for current buffer
    vim.b.disable_autoformat = true
  end
end, {
  desc = "Disable autoformat-on-save",
  bang = true,
})

vim.api.nvim_create_user_command("FormatEnable", function()
  vim.b.disable_autoformat = false
  vim.g.disable_autoformat = false
end, {
  desc = "Re-enable autoformat-on-save",
})

-- Keymaps (optional)
vim.keymap.set("n", "<leader>tf", function()
  vim.g.disable_autoformat = not vim.g.disable_autoformat
  print("Format on save:", vim.g.disable_autoformat and "disabled" or "enabled")
end, { desc = "Toggle format on save" })
