vim.api.nvim_create_user_command("CdGitRoot", function()
  local git_root = require('utils').find_git_root()
  vim.api.nvim_set_current_dir(git_root)
end, {})
