-- config/branch_diff.lua
--
-- Custom mini.diff source that diffs against the branch base (origin/main
-- or nearest stack ancestor) instead of the git index.
--
-- Signs:
--   Blue  = committed/staged change in the branch diff
--   Green = unstaged (buffer differs from index) — overlaid at higher priority
--   Red   = unstaged deletion
--
-- Usage in plugins/init.lua:
--   require('mini.diff').setup({
--     source = require('config.branch_diff').source(),
--     view = { priority = 100 },
--   })

local M = {}

-- ── helpers ──────────────────────────────────────────────────────────────────

local function git(args)
  local out = vim.fn.systemlist("git " .. args)
  if vim.v.shell_error ~= 0 then return nil end
  return out
end

local function git_argv(args)
  local cmd = { "git" }
  for _, a in ipairs(args) do cmd[#cmd + 1] = a end
  local out = vim.fn.systemlist(cmd)
  if vim.v.shell_error ~= 0 then return nil end
  return out
end

local function git_root()
  local out = git("rev-parse --show-toplevel")
  return out and out[1] or nil
end

local function git_relative_path(file, root)
  if root and file:sub(1, #root + 1) == root .. "/" then
    return file:sub(#root + 2)
  end
  return file
end

local function ref_content(root, rel, ref)
  local result = vim.fn.systemlist({ "git", "-C", root, "show", ref .. ":" .. rel })
  if vim.v.shell_error ~= 0 then return nil end
  return table.concat(result, "\n")
end

local function branch_base()
  local branch = git("rev-parse --abbrev-ref HEAD")
  branch = branch and branch[1] or "HEAD"
  local self_remote = "origin/" .. branch

  local lines = git_argv({
    "for-each-ref", "--format=%(refname:short)",
    "--merged", "HEAD", "--no-merged", "origin/main",
    "--sort=-committerdate",
    "refs/remotes/origin/",
  })

  if lines then
    for _, ref in ipairs(lines) do
      if ref ~= self_remote and ref ~= "origin/HEAD" then
        return ref
      end
    end
  end
  return "origin/main"
end

-- ── mini.diff source ─────────────────────────────────────────────────────────
--
-- Provides the branch base content as the reference text. mini.diff then
-- renders blue signs for every line that differs from the base.

function M.source()
  return {
    name = "branch_diff",
    attach = function(buf_id)
      local file = vim.api.nvim_buf_get_name(buf_id)
      if file == "" then return false end
      local root = git_root()
      if not root then return false end
      local rel = git_relative_path(file, root)
      local base = branch_base()
      local text = ref_content(root, rel, base) or ""

      vim.b[buf_id].branch_diff_base = base

      -- Set ref text after mini.diff finishes attaching
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(buf_id) then
          pcall(require("mini.diff").set_ref_text, buf_id, text)
        end
      end)
      return true
    end,
    detach = function(buf_id)
      vim.b[buf_id].branch_diff_base = nil
    end,
  }
end

-- ── unstaged overlay ─────────────────────────────────────────────────────────
--
-- A second sign layer (higher priority than mini.diff) that shows which lines
-- in the buffer differ from the git index. These are your active, unsaved or
-- unstaged edits.

local ns = vim.api.nvim_create_namespace("branch_diff_unstaged")

local function update_unstaged(buf)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  if vim.bo[buf].buftype ~= "" then return end

  local file = vim.api.nvim_buf_get_name(buf)
  if file == "" then return end
  local root = git_root()
  if not root then return end
  local rel = git_relative_path(file, root)

  local index_text = ref_content(root, rel, ":0")
  local buf_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local buf_text = table.concat(buf_lines, "\n") .. "\n"

  if not index_text then
    -- Untracked file — every line is unstaged
    for lnum = 1, #buf_lines do
      vim.api.nvim_buf_set_extmark(buf, ns, lnum - 1, 0, {
        sign_text = "▎",
        sign_hl_group = "BranchDiffUnstagedAdd",
        priority = 200,
      })
    end
    return
  end

  if not index_text:match("\n$") then index_text = index_text .. "\n" end
  if buf_text == index_text then return end

  local ok, hunks = pcall(vim.diff, index_text, buf_text, { result_type = "indices" })
  if not ok or not hunks then return end

  local line_count = #buf_lines
  for _, h in ipairs(hunks) do
    local b_start, b_count = h[3], h[4]
    if b_count == 0 then
      local lnum = math.min(b_start + 1, line_count)
      if lnum >= 1 then
        vim.api.nvim_buf_set_extmark(buf, ns, lnum - 1, 0, {
          sign_text = "▸",
          sign_hl_group = "BranchDiffUnstagedDelete",
          priority = 200,
        })
      end
    else
      for lnum = b_start, math.min(b_start + b_count - 1, line_count) do
        if lnum >= 1 then
          vim.api.nvim_buf_set_extmark(buf, ns, lnum - 1, 0, {
            sign_text = "▎",
            sign_hl_group = "BranchDiffUnstagedAdd",
            priority = 200,
          })
        end
      end
    end
  end
end

local timer = nil
local function schedule_unstaged(buf)
  if timer then timer:stop() end
  timer = vim.defer_fn(function()
    timer = nil
    if vim.api.nvim_buf_is_valid(buf) then
      update_unstaged(buf)
    end
  end, 300)
end

-- ── deletion folds ───────────────────────────────────────────────────────────
--
-- Virtual lines at deletion points showing what was removed.
-- Orange = branch deletion (removed from origin/main). Red = unstaged deletion.
-- Collapsed by default, toggle with <leader>Cx.

local ns_del = vim.api.nvim_create_namespace("branch_diff_deletions")

-- buf → { [extmark_id] = { lines = {...}, expanded = false, anchor = N } }
local del_folds = {}

local function parse_deletion_hunks(old_text, new_text)
  if not old_text or not new_text then return {} end
  if not old_text:match("\n$") then old_text = old_text .. "\n" end
  if not new_text:match("\n$") then new_text = new_text .. "\n" end

  local ok, hunks = pcall(vim.diff, old_text, new_text, { result_type = "indices" })
  if not ok or not hunks then return {} end

  local old_lines = {}
  for line in old_text:gmatch("([^\n]*)\n") do
    old_lines[#old_lines + 1] = line
  end

  local result = {}
  for _, h in ipairs(hunks) do
    local a_start, a_count, b_start, b_count = h[1], h[2], h[3], h[4]
    if a_count > 0 then
      local deleted = {}
      for i = a_start, a_start + a_count - 1 do
        deleted[#deleted + 1] = old_lines[i] or ""
      end
      -- Anchor: line in new text after the deletion
      local anchor = b_start + b_count
      result[#result + 1] = { anchor = anchor, lines = deleted }
    end
  end
  return result
end

local function render_fold(buf, fold_id)
  local folds = del_folds[buf]
  if not folds or not folds[fold_id] then return end
  local fold = folds[fold_id]

  local virt_lines = {}
  local hl = fold.hl or "BranchDiffDelFoldCollapsed"

  if fold.expanded then
    for _, line in ipairs(fold.lines) do
      virt_lines[#virt_lines + 1] = { { "  " .. line, fold.hl_content or "BranchDiffDelContent" } }
    end
  else
    local count = #fold.lines
    local summary = string.format("  ▸ %d line%s deleted", count, count == 1 and "" or "s")
    virt_lines[#virt_lines + 1] = { { summary, hl } }
  end

  local line_count = vim.api.nvim_buf_line_count(buf)
  local anchor = math.max(0, math.min(fold.anchor - 1, line_count - 1))

  -- Update the existing extmark
  pcall(vim.api.nvim_buf_set_extmark, buf, ns_del, anchor, 0, {
    id = fold_id,
    virt_lines = virt_lines,
    virt_lines_above = false,
  })
end

local function update_deletion_folds(buf)
  vim.api.nvim_buf_clear_namespace(buf, ns_del, 0, -1)
  del_folds[buf] = {}

  if not vim.api.nvim_buf_is_valid(buf) then return end
  if vim.bo[buf].buftype ~= "" then return end
  local file = vim.api.nvim_buf_get_name(buf)
  if file == "" then return end
  local root = git_root()
  if not root then return end
  local rel = git_relative_path(file, root)

  local base = vim.b[buf].branch_diff_base or branch_base()
  local base_text = ref_content(root, rel, base)
  local head_text = ref_content(root, rel, "HEAD")
  local index_text = ref_content(root, rel, ":0")
  local buf_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local buf_text = table.concat(buf_lines, "\n") .. "\n"

  -- Branch deletions: lines in base that aren't in HEAD
  if base_text and head_text then
    local branch_dels = parse_deletion_hunks(base_text, head_text)
    for _, hunk in ipairs(branch_dels) do
      local id = vim.api.nvim_buf_set_extmark(buf, ns_del, 0, 0, {})
      del_folds[buf][id] = {
        lines = hunk.lines,
        anchor = hunk.anchor,
        expanded = false,
        hl = "BranchDiffDelFoldCollapsed",
        hl_content = "BranchDiffDelContentBranch",
      }
      render_fold(buf, id)
    end
  end

  -- Fresh deletions: lines in index that aren't in the buffer
  if index_text then
    local fresh_dels = parse_deletion_hunks(index_text, buf_text)
    for _, hunk in ipairs(fresh_dels) do
      local id = vim.api.nvim_buf_set_extmark(buf, ns_del, 0, 0, {})
      del_folds[buf][id] = {
        lines = hunk.lines,
        anchor = hunk.anchor,
        expanded = false,
        hl = "BranchDiffDelFoldFresh",
        hl_content = "BranchDiffDelContentFresh",
      }
      render_fold(buf, id)
    end
  end
end

function M.toggle_fold()
  local buf = vim.api.nvim_get_current_buf()
  local folds = del_folds[buf]
  if not folds then return end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1 -- 0-indexed

  -- Find the fold nearest to the cursor
  local best_id, best_dist = nil, math.huge
  for id, fold in pairs(folds) do
    local anchor = math.max(0, fold.anchor - 1)
    local dist = math.abs(anchor - row)
    if dist < best_dist then
      best_dist = dist
      best_id = id
    end
  end

  if best_id and best_dist <= 1 then
    folds[best_id].expanded = not folds[best_id].expanded
    render_fold(buf, best_id)
  end
end

-- ── setup ────────────────────────────────────────────────────────────────────

function M.setup()
  -- Blue = branch diff (mini.diff signs)
  vim.api.nvim_set_hl(0, "MiniDiffSignAdd", { fg = "#7aa2f7" })
  vim.api.nvim_set_hl(0, "MiniDiffSignChange", { fg = "#7aa2f7" })
  vim.api.nvim_set_hl(0, "MiniDiffSignDelete", { fg = "#7aa2f7" })

  -- Green = unstaged overlay
  vim.api.nvim_set_hl(0, "BranchDiffUnstagedAdd", { fg = "#73daca", bold = true })
  vim.api.nvim_set_hl(0, "BranchDiffUnstagedDelete", { fg = "#f7768e", bold = true })

  -- Deletion folds
  vim.api.nvim_set_hl(0, "BranchDiffDelFoldCollapsed", { fg = "#e0af68", italic = true })  -- orange
  vim.api.nvim_set_hl(0, "BranchDiffDelFoldFresh", { fg = "#f7768e", italic = true })      -- red
  vim.api.nvim_set_hl(0, "BranchDiffDelContentBranch", { fg = "#e0af68", bg = "#1a1b26" }) -- orange, dimmed
  vim.api.nvim_set_hl(0, "BranchDiffDelContentFresh", { fg = "#f7768e", bg = "#1a1b26" })  -- red, dimmed

  -- Toggle deletion fold under cursor
  vim.keymap.set("n", "<leader>Cx", M.toggle_fold, { noremap = true, silent = true, desc = "Toggle deletion fold" })

  vim.api.nvim_create_autocmd("BufEnter", {
    callback = function()
      local buf = vim.api.nvim_get_current_buf()
      vim.defer_fn(function()
        if vim.api.nvim_buf_is_valid(buf) then
          update_unstaged(buf)
          update_deletion_folds(buf)
        end
      end, 200)
    end,
  })

  vim.api.nvim_create_autocmd("BufWritePost", {
    callback = function()
      local buf = vim.api.nvim_get_current_buf()
      vim.defer_fn(function()
        if not vim.api.nvim_buf_is_valid(buf) then return end
        -- Re-set the branch base ref (mini.diff resets its source on write)
        local file = vim.api.nvim_buf_get_name(buf)
        if file == "" then return end
        local root = git_root()
        if not root then return end
        local rel = git_relative_path(file, root)
        local base = vim.b[buf].branch_diff_base or branch_base()
        local text = ref_content(root, rel, base) or ""
        pcall(require("mini.diff").set_ref_text, buf, text)
        update_unstaged(buf)
        update_deletion_folds(buf)
      end, 100)
    end,
  })

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    callback = function()
      schedule_unstaged(vim.api.nvim_get_current_buf())
    end,
  })
end

return M
