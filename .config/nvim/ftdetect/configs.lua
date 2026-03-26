vim.filetype.add({
  extension = {
    tmux = 'tmux',
  },
  pattern = {
    -- Git config: includes and identity fragments in .config/git/
    ['.*/%.config/git/.*'] = function(path)
      if vim.fn.fnamemodify(path, ':t') == 'gitk' then
        return nil
      end
      return 'gitconfig'
    end,
    -- Git config: worktree-specific config in .git/
    ['.*/%.git/config%..*'] = 'gitconfig',
    -- SSH config: files in .ssh/ that aren't keys or known non-config files
    ['.*/%.ssh/.*'] = function(path)
      local name = vim.fn.fnamemodify(path, ':t')
      local ext = vim.fn.fnamemodify(path, ':e')
      if name:match('^id_') or ext == 'pub' or name == 'known_hosts'
        or name == 'authorized_keys' or name == 'rc' or name == 'environment' then
        return nil
      end
      return 'sshconfig'
    end,
  },
})
