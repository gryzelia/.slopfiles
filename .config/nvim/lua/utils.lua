local M = {}

-- Function to find the git root directory based on the current buffer's path
M.find_git_root = function()
  -- Use the current buffer's path as the starting point for the git search
  local current_file = vim.api.nvim_buf_get_name(0)
  local current_dir
  local cwd = vim.fn.getcwd()
  -- If the buffer is not associated with a file, return nil
  if current_file == '' then
    current_dir = cwd
  else
    -- Extract the directory from the current file's path
    current_dir = vim.fn.fnamemodify(current_file, ':h')
  end

  -- Find the Git root directory from the current file's path
  local git_root = vim.fn.systemlist('git -C ' .. vim.fn.escape(current_dir, ' ') .. ' rev-parse --show-toplevel')[1]
  if vim.v.shell_error ~= 0 then
    print 'Not a git repository. Searching on current working directory'
    return cwd
  end
  return git_root
end

M.relative_to = function(parent, child)
    local p = vim.fs.normalize(vim.fn.fnamemodify(parent, ':p'))
    local c = vim.fs.normalize(vim.fn.fnamemodify(child, ':p'))
    if c:find(p, 1, true) == 1 then
      return c:sub(#p + 2) -- +2 to skip the trailing separator
    end
    return nil
  end



return M
