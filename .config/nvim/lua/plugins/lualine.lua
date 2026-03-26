local repo_stats = {}
local function update_repo_stats()
  vim.fn.jobstart({ 'git', 'status', '--porcelain=v1' }, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      local staged, modified, renamed, deleted, untracked, conflicted = 0, 0, 0, 0, 0, 0
      for _, line in ipairs(data) do
        if line ~= '' then
          local xy = line:sub(1, 2)
          if xy:match('[UA][UA]') or xy == 'DD' or xy == 'AA' then
            conflicted = conflicted + 1
          elseif xy:sub(2, 2) == '?' then
            untracked = untracked + 1
          else
            if xy:sub(1, 1):match('[MADRC]') then staged = staged + 1 end
            if xy:sub(1, 1) == 'R' then renamed = renamed + 1 end
            if xy:sub(2, 2) == 'M' then modified = modified + 1 end
            if xy:sub(2, 2) == 'D' then deleted = deleted + 1 end
          end
        end
      end
      repo_stats = {
        staged = staged,
        modified = modified,
        renamed = renamed,
        deleted = deleted,
        untracked = untracked,
        conflicted = conflicted,
      }
    end,
  })
end

vim.api.nvim_create_autocmd({ 'BufWritePost', 'VimEnter', 'FocusGained' }, {
  callback = update_repo_stats,
})

local stat_components = {
  { key = 'staged',     prefix = 'S:', color = { fg = '#98c379' } },
  { key = 'modified',   prefix = 'M:', color = { fg = '#61afef' } },
  { key = 'renamed',    prefix = 'R:', color = { fg = '#c678dd' } },
  { key = 'deleted',    prefix = 'D:', color = { fg = '#e06c75' } },
  { key = 'untracked',  prefix = '?:', color = { fg = '#e5c07b' } },
  { key = 'conflicted', prefix = '!:', color = { fg = '#ff5874' } },
}

local function make_stat_component(spec)
  return {
    function() return spec.prefix .. repo_stats[spec.key] end,
    cond = function() return (repo_stats[spec.key] or 0) > 0 end,
    color = spec.color,
    separator = '',
    padding = { left = 1, right = 0 },
  }
end

return {
  -- Set lualine as statusline
  'nvim-lualine/lualine.nvim',
  -- See `:help lualine.txt`
  opts = {
    options = {
      icons_enabled = true,
      theme = 'onedark',
      component_separators = '|',
      section_separators = '',
    },
    sections = {
      lualine_c = vim.list_extend(
        vim.tbl_map(make_stat_component, stat_components),
        {
          {
            function() return '|' end,
            cond = function() return next(repo_stats) ~= nil end,
            separator = '',
            padding = { left = 1, right = 0 },
          },
          { 'filename', path = 1, shorting_target = 48 },
        }
      ),
      lualine_y = {
        { 'searchcount', maxcount = 999999 },
        'selectioncount',
        'progress',
      },
    },
    inactive_sections = {
      lualine_c = {
        {
          'filename',
          path = 1,
        },
      },
      lualine_x = {
        { 'searchcount', maxcount = 999999 },
      },
      lualine_y = {
        { 'location' },
      },
    },
  },
}
