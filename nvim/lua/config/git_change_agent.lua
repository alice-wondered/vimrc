local uv = vim.loop

local M = {}
local last_root_started = nil
local session_client_id = string.format("nvim-%d-%d", vim.fn.getpid(), math.floor(uv.hrtime() / 1000000))
local leased_roots = {}
local heartbeat_timer = nil

local function executable()
  if vim.g.git_change_agent_cmd and vim.g.git_change_agent_cmd ~= "" then
    return vim.g.git_change_agent_cmd
  end
  local candidates = {
    vim.env.HOME .. "/src/nvim-git-change-mcp/git-change-agent",
    vim.fn.stdpath("config") .. "/tools/git-change-agent/git-change-agent",
  }

  for _, path in ipairs(candidates) do
    if vim.fn.executable(path) == 1 then
      return path
    end
  end

  return candidates[1]
end

local function has_executable()
  return vim.fn.executable(executable()) == 1
end

local function run_async(args)
  if not has_executable() then
    return
  end

  local cmd = { executable() }
  vim.list_extend(cmd, args)

  vim.fn.jobstart(cmd, {
    detach = true,
    on_stderr = function(_, data)
      if not vim.g.git_change_agent_debug then
        return
      end
      if data and #data > 0 and data[1] ~= "" then
        vim.schedule(function()
          vim.notify("git-change-agent: " .. table.concat(data, "\n"), vim.log.levels.DEBUG)
        end)
      end
    end,
  })
end

local function in_git_repo(path)
  local result = vim.fn.system({ "git", "-C", path, "rev-parse", "--is-inside-work-tree" })
  return vim.v.shell_error == 0 and result:match("true") ~= nil
end

local function git_root(path)
  local root = vim.fn.system({ "git", "-C", path, "rev-parse", "--show-toplevel" })
  if vim.v.shell_error ~= 0 then
    return nil
  end
  root = vim.fn.trim(root)
  if root == "" then
    return nil
  end
  return root
end

function M.start_for(path)
  local root = git_root(path)
  if not root then
    return
  end
  if root == last_root_started then
    if not leased_roots[root] then
      leased_roots[root] = true
      run_async({ "register", "--path", root, "--client-id", session_client_id })
    end
    return
  end
  last_root_started = root
  run_async({ "start", "--path", root })
  if not leased_roots[root] then
    leased_roots[root] = true
    run_async({ "register", "--path", root, "--client-id", session_client_id })
  end
end

function M.notify_save(file)
  if file == "" then
    return
  end
  local dir = vim.fn.fnamemodify(file, ":p:h")
  if not in_git_repo(dir) then
    return
  end
  M.start_for(dir)
  run_async({ "notify", "--path", file })
end

function M.setup()
  vim.api.nvim_create_user_command("GitAgentStart", function()
    M.start_for(vim.loop.cwd())
  end, { desc = "Start git-change-agent for cwd" })

  vim.api.nvim_create_user_command("GitAgentStop", function()
    run_async({ "stop", "--path", vim.loop.cwd() })
  end, { desc = "Stop git-change-agent for cwd" })

  vim.api.nvim_create_user_command("GitAgentStatus", function()
    if not has_executable() then
      vim.notify("git-change-agent binary not found", vim.log.levels.WARN)
      return
    end
    local out = vim.fn.system({ executable(), "status", "--path", vim.loop.cwd() })
    if vim.v.shell_error ~= 0 then
      vim.notify("git-change-agent status failed", vim.log.levels.WARN)
      return
    end
    vim.notify(out, vim.log.levels.INFO)
  end, { desc = "Show git-change-agent status" })

  vim.api.nvim_create_user_command("GitAgentWhere", function()
    if not has_executable() then
      vim.notify("git-change-agent binary not found", vim.log.levels.WARN)
      return
    end
    local out = vim.fn.system({ executable(), "where", "--path", vim.loop.cwd() })
    vim.notify(out, vim.log.levels.INFO)
  end, { desc = "Show git-change-agent paths" })

  vim.api.nvim_create_autocmd("VimEnter", {
    callback = function()
      M.start_for(uv.cwd())
    end,
  })

  vim.api.nvim_create_autocmd("DirChanged", {
    callback = function(args)
      local cwd = args.file ~= "" and args.file or uv.cwd()
      M.start_for(cwd)
    end,
  })

  vim.api.nvim_create_autocmd("BufEnter", {
    callback = function(args)
      local file = args.file
      if not file or file == "" then
        return
      end
      local dir = vim.fn.fnamemodify(file, ":p:h")
      M.start_for(dir)
    end,
  })

  vim.api.nvim_create_autocmd("BufWritePost", {
    callback = function(args)
      M.notify_save(args.file)
    end,
  })

  heartbeat_timer = uv.new_timer()
  if heartbeat_timer then
    heartbeat_timer:start(
      15000,
      15000,
      vim.schedule_wrap(function()
        for root, _ in pairs(leased_roots) do
          run_async({ "heartbeat", "--path", root, "--client-id", session_client_id })
        end
      end)
    )
  end

  vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      for root, _ in pairs(leased_roots) do
        run_async({ "unregister", "--path", root, "--client-id", session_client_id })
      end
      if heartbeat_timer then
        heartbeat_timer:stop()
        heartbeat_timer:close()
        heartbeat_timer = nil
      end
    end,
  })
end

return M
