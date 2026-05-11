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

local function git(args)
  local out = vim.fn.systemlist('git ' .. args)
  if vim.v.shell_error ~= 0 then
    return nil
  end
  return out
end

local function git_root()
  local out = git('rev-parse --show-toplevel')
  if not out or not out[1] then
    return nil
  end
  return out[1]
end

local function resolve_diff_base()
  local candidates = {
    vim.g.branch_diff_base,
    'origin/main',
    'origin/master',
    'main',
    'master',
  }

  for _, ref in ipairs(candidates) do
    if ref and ref ~= '' then
      local ok = git('rev-parse --verify --quiet ' .. vim.fn.shellescape(ref))
      if ok then
        return ref
      end
    end
  end

  return 'main'
end

vim.g.branch_diff_base = vim.g.branch_diff_base or resolve_diff_base()

local function set_diff_base(ref)
  if not ref or ref == '' then
    return
  end
  local ok = git('rev-parse --verify --quiet ' .. vim.fn.shellescape(ref))
  if not ok then
    vim.notify(('Invalid git ref: %s'):format(ref), vim.log.levels.WARN)
    return
  end
  vim.g.branch_diff_base = ref
  vim.notify(('Branch diff base set to %s'):format(ref), vim.log.levels.INFO)
end

local function pick_diff_base()
  local items = {}
  local branches = git("for-each-ref --format='%(refname:short)' refs/heads refs/remotes") or {}
  local commits = git('log --oneline --no-decorate -n 40') or {}

  for _, ref in ipairs(branches) do
    items[#items + 1] = ('%s\tbranch\t%s'):format(ref, ref)
  end

  for _, line in ipairs(commits) do
    local sha, msg = line:match('^(%S+)%s+(.+)$')
    if sha and msg then
      items[#items + 1] = ('%s\tcommit\t%s'):format(sha, msg)
    end
  end

  fzf.fzf_exec(items, {
    prompt = 'diff-base> ',
    fzf_opts = {
      ['--delimiter'] = '\t',
      ['--with-nth'] = '2..',
      ['--tiebreak'] = 'index',
    },
    actions = {
      ['default'] = function(selected)
        if not selected or not selected[1] then
          return
        end
        local ref = selected[1]:match('^([^\t]+)')
        set_diff_base(ref)
      end,
    },
  })
end

local function open_branch_diff_files(include_branch_changes)
  local root = git_root()
  if not root then
    return false
  end

  local base = vim.g.branch_diff_base or resolve_diff_base()
  local changed = {}
  if include_branch_changes then
    changed = git('diff --name-only --diff-filter=ACMR ' .. vim.fn.shellescape(base) .. '...HEAD') or {}
  end
  local status = git('status --porcelain=1') or {}
  local seen = {}
  local items = {}

  for _, path in ipairs(changed) do
    if path ~= '' and not seen[path] then
      seen[path] = true
      items[#items + 1] = path
    end
  end

  for _, line in ipairs(status) do
    local path = line:sub(4)
    if path:find(' -> ', 1, true) then
      path = path:match(' -> (.+)$') or path
    end

    if path ~= '' and not seen[path] then
      seen[path] = true
      items[#items + 1] = path
    end
  end

  if #items == 0 then
    return false
  end

  fzf.fzf_exec(items, {
    cwd = root,
    prompt = include_branch_changes and ('branch+work(%s)> '):format(base) or 'working> ',
    previewer = 'builtin',
    fzf_opts = {
      ['--tiebreak'] = 'index',
    },
    actions = {
      ['default'] = function(selected)
        if not selected or not selected[1] then
          return
        end
        local path = selected[1]:match('^([^\t]+)')
        vim.cmd('edit ' .. vim.fn.fnameescape(root .. '/' .. path))
      end,
      ['ctrl-v'] = function(selected)
        if not selected or not selected[1] then
          return
        end
        local path = selected[1]:match('^([^\t]+)')
        vim.cmd('vsplit ' .. vim.fn.fnameescape(root .. '/' .. path))
      end,
      ['ctrl-s'] = function(selected)
        if not selected or not selected[1] then
          return
        end
        local path = selected[1]:match('^([^\t]+)')
        vim.cmd('split ' .. vim.fn.fnameescape(root .. '/' .. path))
      end,
    },
  })

  return true
end

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

-- Toggle mini.files on the current file's directory
local mf = require("mini.files")

local function toggle_mini_files()
  if not mf.close() then
    local name = vim.api.nvim_buf_get_name(0)
    local path = (name == "" and vim.loop.cwd()) or vim.fn.fnamemodify(name, ":p:h")
    mf.open(path, false)
  end
end

vim.keymap.set("n", "<leader>fe", function()
  toggle_mini_files()
end, { desc = "MiniFiles toggle (buffer dir or CWD)" })

vim.keymap.set("n", "<leader>fE", function()
  if not open_branch_diff_files(false) then
    vim.notify("No changed files found in working tree", vim.log.levels.INFO)
  end
end, { desc = "Working tree changed files" })

vim.keymap.set("n", "<leader>fD", function()
  if not open_branch_diff_files(true) then
    vim.notify("No changed files found vs diff base", vim.log.levels.INFO)
  end
end, { desc = "Branch diff files vs base" })

vim.keymap.set('n', '<leader>fB', pick_diff_base, { desc = 'Pick branch diff base' })

vim.api.nvim_create_user_command('BranchDiffBase', function(args)
  set_diff_base(args.args)
end, {
  nargs = 1,
  desc = 'Set branch diff base git ref',
})

vim.api.nvim_create_user_command('BranchDiffPickBase', pick_diff_base, {
  desc = 'Pick branch diff base ref',
})

vim.api.nvim_create_user_command('BranchDiffFiles', function()
  open_branch_diff_files(true)
end, {
  desc = 'Open files changed against branch diff base',
})
