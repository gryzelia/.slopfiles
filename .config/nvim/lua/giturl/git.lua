local M = {}

--- Find the git root directory for a given path.
---@param path? string file or directory path (defaults to cwd)
---@return string|nil root
---@return string|nil err
function M.find_git_root(path)
  local dir = path or vim.fn.getcwd()
  -- If path is a file, get its directory
  if vim.fn.isdirectory(dir) == 0 then
    dir = vim.fn.fnamemodify(dir, ':h')
  end
  local root = vim.fn.systemlist('git -C ' .. vim.fn.shellescape(dir) .. ' rev-parse --show-toplevel')[1]
  if vim.v.shell_error ~= 0 then
    return nil, 'Not a git repository'
  end
  return root
end

--- Return the relative path of abs_path within root.
---@param root string
---@param abs_path string
---@return string|nil
function M.relative_path(root, abs_path)
  local p = vim.fs.normalize(vim.fn.fnamemodify(root, ':p'))
  local c = vim.fs.normalize(vim.fn.fnamemodify(abs_path, ':p'))
  if c:find(p, 1, true) == 1 then
    return c:sub(#p + 2) -- +2 to skip trailing separator
  end
  return nil
end

--- Extract the hostname from ssh -G output lines.
---@param lines string[]
---@param fallback string
---@return string hostname
function M._parse_ssh_hostname(lines, fallback)
  for _, line in ipairs(lines) do
    local hostname = line:match('^hostname%s+(.+)$')
    if hostname then
      return hostname
    end
  end
  return fallback
end

--- Resolve an SSH destination to its real hostname via ssh -G.
--- Accepts any SSH destination format: host, user@host, ssh://[user@]host.
---@param dest string
---@return string hostname
function M._resolve_ssh_host(dest)
  local lines = vim.fn.systemlist('ssh -G ' .. vim.fn.shellescape(dest))
  if vim.v.shell_error ~= 0 then
    -- Fallback: strip ssh:// and user@ prefixes
    local h = dest:gsub('^ssh://', '')
    return h:match('@(.+)$') or h
  end
  return M._parse_ssh_hostname(lines, dest)
end

--- Parse a remote URL string into { host, owner, repo }.
--- SSH destinations are resolved to hostnames via ssh -G.
---@param url string
---@return table|nil parsed { host, owner, repo }
---@return string|nil err
function M._parse_url(url)
  local host, path
  -- HTTPS: https://host/owner/repo.git
  host, path = url:match('^https?://([^/]+)/(.+)$')
  if not host then
    -- SSH: ssh://[user@]host[:port]/path or [user@]host:path or alias:path
    local dest
    dest, path = url:match('^(ssh://[^/]+)/(.+)$')
    if not dest then
      dest, path = url:match('^(.-):(.+)$')
    end
    if dest then
      host = M._resolve_ssh_host(dest)
    end
  end
  if not host or not path then
    return nil, 'Unsupported remote URL format: ' .. url
  end
  -- Strip trailing .git
  path = path:gsub('%.git$', '')
  -- Split into owner and repo (owner may contain slashes for nested groups)
  local last_slash = path:find('/[^/]*$')
  if not last_slash then
    return nil, 'Cannot parse owner/repo from: ' .. path
  end
  local owner = path:sub(1, last_slash - 1)
  local repo = path:sub(last_slash + 1)
  return { host = host, owner = owner, repo = repo }
end

--- Parse a git remote URL into { host, owner, repo }.
---@param git_root string
---@param remote_name string
---@return table|nil parsed { host, owner, repo }
---@return string|nil err
function M.parse_remote_url(git_root, remote_name)
  local url = vim.fn.systemlist('git -C ' .. vim.fn.shellescape(git_root) .. ' remote get-url ' .. vim.fn.shellescape(remote_name))[1]
  if vim.v.shell_error ~= 0 or not url then
    return nil, 'Failed to get remote URL for ' .. remote_name
  end
  return M._parse_url(url)
end

--- Get the current git ref, preferring the remote tracking branch name.
--- Falls back to local branch name, then SHA if detached.
---@param git_root string
---@param remote? string remote name to strip prefix from (default: 'origin')
---@return string
function M.get_ref(git_root, remote)
  remote = remote or 'origin'
  -- Try to get the remote tracking branch (e.g. "origin/main")
  local tracking = vim.fn.systemlist(
    'git -C ' .. vim.fn.shellescape(git_root) .. ' rev-parse --abbrev-ref --symbolic-full-name @{upstream}'
  )[1]
  if vim.v.shell_error == 0 and tracking and tracking ~= '' then
    -- Strip the remote prefix (e.g. "origin/main" -> "main")
    local prefix = remote .. '/'
    if tracking:find(prefix, 1, true) == 1 then
      return tracking:sub(#prefix + 1)
    end
    -- Tracking a different remote — still strip its prefix
    local other_remote, branch = tracking:match('^([^/]+)/(.+)$')
    if other_remote and branch then
      return branch
    end
    return tracking
  end

  -- No tracking branch — try local branch name
  local ref = vim.fn.systemlist('git -C ' .. vim.fn.shellescape(git_root) .. ' rev-parse --abbrev-ref HEAD')[1]
  if vim.v.shell_error ~= 0 or not ref or ref == '' or ref == 'HEAD' then
    -- Detached HEAD, use SHA
    ref = vim.fn.systemlist('git -C ' .. vim.fn.shellescape(git_root) .. ' rev-parse HEAD')[1]
  end
  return ref or 'HEAD'
end

--- Resolve a ref to its commit SHA.
---@param git_root string
---@param ref? string ref to resolve (default: HEAD)
---@return string
function M.get_sha(git_root, ref)
  ref = ref or 'HEAD'
  local sha = vim.fn.systemlist('git -C ' .. vim.fn.shellescape(git_root) .. ' rev-parse ' .. vim.fn.shellescape(ref))[1]
  return sha or ref
end

--- List remotes.
---@param git_root string
---@return string[]
function M.list_remotes(git_root)
  local lines = vim.fn.systemlist('git -C ' .. vim.fn.shellescape(git_root) .. ' remote')
  if vim.v.shell_error ~= 0 then
    return {}
  end
  return lines
end

--- List branches on a remote.
---@param git_root string
---@param remote string
---@return string[]
function M.list_branches(git_root, remote)
  local lines = vim.fn.systemlist(
    'git -C ' .. vim.fn.shellescape(git_root) .. ' branch -r --list ' .. vim.fn.shellescape(remote .. '/*')
  )
  if vim.v.shell_error ~= 0 then
    return {}
  end
  local branches = {}
  local prefix = remote .. '/'
  for _, line in ipairs(lines) do
    local trimmed = vim.trim(line)
    -- Skip HEAD pointer
    if not trimmed:match('->') then
      -- Strip remote prefix
      if trimmed:find(prefix, 1, true) == 1 then
        trimmed = trimmed:sub(#prefix + 1)
      end
      table.insert(branches, trimmed)
    end
  end
  return branches
end

--- List tags sorted by version descending.
---@param git_root string
---@return string[]
function M.list_tags(git_root)
  local lines = vim.fn.systemlist('git -C ' .. vim.fn.shellescape(git_root) .. ' tag --sort=-v:refname')
  if vim.v.shell_error ~= 0 then
    return {}
  end
  return lines
end

--- List recent commits.
---@param git_root string
---@param n number max commits
---@param branch? string branch/tag to list from
---@return table[] { { sha = string, message = string } }
function M.list_commits(git_root, n, branch)
  local cmd = 'git -C ' .. vim.fn.shellescape(git_root) .. ' log --oneline -n ' .. tostring(n)
  if branch then
    cmd = cmd .. ' ' .. vim.fn.shellescape(branch)
  end
  local lines = vim.fn.systemlist(cmd)
  if vim.v.shell_error ~= 0 then
    return {}
  end
  local commits = {}
  for _, line in ipairs(lines) do
    local sha, message = line:match('^(%S+)%s+(.+)$')
    if sha then
      table.insert(commits, { sha = sha, message = message })
    end
  end
  return commits
end

return M
