local git = require('giturl.git')

local M = {}

--- Parse a buffer name into git context.
---@param bufname string
---@return table|nil parsed { git_root: string, ref: string|nil, filepath: string }
---@return string|nil err
function M.parse(bufname)
  if not bufname or bufname == '' then
    return nil, 'Empty buffer name'
  end

  -- Fugitive: fugitive:///path/to/repo/.git//ref/filepath
  --       or: fugitive:///path/to/worktree//ref/filepath
  local git_path, rest = bufname:match('^fugitive://(.+)//(.+)$')
  if git_path and rest then
    local git_root = git_path:gsub('/$', ''):gsub('/%.git$', '')
    -- Split rest at first / into ref and filepath
    local ref, filepath = rest:match('^([^/]+)/(.+)$')
    if ref and filepath then
      return { git_root = git_root, ref = ref, filepath = filepath }
    end
    -- No slash means entire rest is the filepath with no parseable ref
    return nil, 'Cannot parse fugitive path: ' .. bufname
  end

  -- Regular buffer: resolve via git
  local abs_path = vim.fn.fnamemodify(bufname, ':p')
  local root, err = git.find_git_root(abs_path)
  if not root then
    return nil, err
  end
  local rel = git.relative_path(root, abs_path)
  if not rel then
    return nil, 'File is not inside git root: ' .. abs_path
  end
  return { git_root = root, ref = nil, filepath = rel }
end

return M
