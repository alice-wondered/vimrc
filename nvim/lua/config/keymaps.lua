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

local function jj_run(args, root)
  local cmd = { 'jj' }
  for _, a in ipairs(args) do cmd[#cmd + 1] = a end
  local obj = vim.system(cmd, { cwd = root, text = true }):wait()
  if obj.code ~= 0 then return nil end
  return obj.stdout
end

local function jj_lines(args, root)
  local out = jj_run(args, root)
  if not out then return nil end
  local lines = {}
  for line in out:gmatch('([^\n]*)\n?') do
    if line ~= '' then lines[#lines + 1] = line end
  end
  return lines
end

-- root_info resolves for git, colocated git+jj, and bare jj workspaces (no
-- .git). git first — colocated repos answer to both, so behavior there is
-- unchanged; jj is the fallback for a workspace git can't see at all.
local function root_info()
  local out = git('rev-parse --show-toplevel')
  if out and out[1] then
    return { root = out[1], kind = 'git' }
  end
  local jj_out = vim.fn.systemlist('jj root')
  if vim.v.shell_error ~= 0 or not jj_out or not jj_out[1] then
    return nil
  end
  return { root = jj_out[1], kind = 'jj' }
end

local function resolve_diff_base(kind)
  if kind == 'jj' then return 'trunk()' end

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

do
  local info = root_info()
  vim.g.branch_diff_kind = info and info.kind or 'git'
  vim.g.branch_diff_base = vim.g.branch_diff_base or resolve_diff_base(vim.g.branch_diff_kind)
end

local function set_diff_base(ref)
  if not ref or ref == '' then
    return
  end
  local info = root_info()
  local kind = info and info.kind or 'git'

  local valid
  if kind == 'jj' then
    valid = jj_run({ 'log', '-r', ref, '--limit', '1', '--no-graph' }, info.root) ~= nil
  else
    valid = git('rev-parse --verify --quiet ' .. vim.fn.shellescape(ref)) ~= nil
  end

  if not valid then
    vim.notify(('Invalid %s ref: %s'):format(kind, ref), vim.log.levels.WARN)
    return
  end
  vim.g.branch_diff_base = ref
  vim.notify(('Branch diff base set to %s'):format(ref), vim.log.levels.INFO)
end

local function pick_diff_base()
  local info = root_info()
  local root = info and info.root
  local kind = info and info.kind or 'git'
  local items = {}

  if kind == 'jj' then
    local revs = jj_lines({
      'log', '-r', 'trunk()..@-', '--no-graph',
      '-T', 'change_id.short() ++ "\\t" ++ description.first_line() ++ "\\n"',
    }, root) or {}
    local bookmarks = jj_lines({ 'bookmark', 'list', '-T', 'name ++ "\\n"' }, root) or {}

    items[#items + 1] = ('%s\trevset\ttrunk()'):format('trunk()')
    for _, b in ipairs(bookmarks) do
      items[#items + 1] = ('%s\tbookmark\t%s'):format(b, b)
    end
    for _, line in ipairs(revs) do
      local cid, desc = line:match('^([^\t]+)\t(.*)$')
      if cid and cid ~= '' then
        items[#items + 1] = ('%s\tchange\t%s'):format(cid, desc ~= '' and desc or '(no description)')
      end
    end
  else
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
  local info = root_info()
  if not info then
    return false
  end
  local root, kind = info.root, info.kind

  local base = vim.g.branch_diff_base or resolve_diff_base(kind)
  local changed = {}
  local status = {}

  if kind == 'jj' then
    if include_branch_changes then
      changed = jj_lines({ 'diff', '--name-only', '-r', base .. '..@' }, root) or {}
    end
    -- jj has no index — the working copy IS `@`; its uncommitted delta
    -- against the parent is the "working tree" analog of `git status`.
    status = jj_lines({ 'diff', '--name-only', '-r', '@-..@' }, root) or {}
  else
    if include_branch_changes then
      changed = git('diff --name-only --diff-filter=ACMR ' .. vim.fn.shellescape(base) .. '...HEAD') or {}
    end
    for _, line in ipairs(git('status --porcelain=1') or {}) do
      local path = line:sub(4)
      if path:find(' -> ', 1, true) then
        path = path:match(' -> (.+)$') or path
      end
      status[#status + 1] = path
    end
  end

  local seen = {}
  local items = {}

  for _, path in ipairs(changed) do
    if path ~= '' and not seen[path] then
      seen[path] = true
      items[#items + 1] = path
    end
  end

  for _, path in ipairs(status) do
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

-- jj commit/bookmark pickers — only reachable for bare jj workspaces (no
-- .git); colocated repos keep the fzf-lua git_* pickers below.

local function show_jj_diff(root, rev, title)
  local out = jj_run({ 'show', '-r', rev, '--no-color' }, root)
  if not out then
    vim.notify('jj show failed for ' .. rev, vim.log.levels.WARN)
    return
  end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].filetype = 'diff'
  vim.api.nvim_buf_set_name(buf, 'jj://show/' .. title)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(out, '\n'))
  vim.cmd('botright split')
  vim.api.nvim_win_set_buf(vim.api.nvim_get_current_win(), buf)
end

local function jj_commits_picker(root)
  local lines = jj_lines({
    'log', '-r', 'trunk()..@', '--no-graph',
    '-T', 'change_id.short() ++ "\\t" ++ description.first_line() ++ "\\n"',
  }, root) or {}

  local items = {}
  for _, line in ipairs(lines) do
    local cid, desc = line:match('^([^\t]+)\t(.*)$')
    if cid and cid ~= '' then
      items[#items + 1] = ('%s\t%s'):format(cid, desc ~= '' and desc or '(no description)')
    end
  end

  fzf.fzf_exec(items, {
    prompt = 'jj-commits> ',
    fzf_opts = { ['--delimiter'] = '\t', ['--tiebreak'] = 'index' },
    actions = {
      ['default'] = function(selected)
        if not selected or not selected[1] then return end
        local cid = selected[1]:match('^([^\t]+)')
        show_jj_diff(root, cid, cid)
      end,
    },
  })
end

local function jj_bookmarks_picker(root)
  local items = jj_lines({ 'bookmark', 'list', '-T', 'name ++ "\\n"' }, root) or {}

  fzf.fzf_exec(items, {
    prompt = 'jj-bookmarks> ',
    fzf_opts = { ['--tiebreak'] = 'index' },
    actions = {
      ['default'] = function(selected)
        if not selected or not selected[1] then return end
        show_jj_diff(root, selected[1], selected[1])
      end,
    },
  })
end

-- git / jj — kind dispatched per-repo; colocated repos keep the git path.
map('n', '<leader>gf', fzf.git_files, opts)

map('n', '<leader>gc', function()
  local info = root_info()
  if info and info.kind == 'jj' then
    jj_commits_picker(info.root)
  else
    fzf.git_commits()
  end
end, opts)

map('n', '<leader>gb', function()
  local info = root_info()
  if info and info.kind == 'jj' then
    jj_bookmarks_picker(info.root)
  else
    fzf.git_branches()
  end
end, opts)

map('n', '<leader>gs', function()
  local info = root_info()
  if info and info.kind == 'jj' then
    if not open_branch_diff_files(false) then
      vim.notify('No changed files in @', vim.log.levels.INFO)
    end
  else
    fzf.git_status()
  end
end, opts)

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
