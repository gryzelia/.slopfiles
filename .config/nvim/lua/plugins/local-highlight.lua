return {
  -- Set lualine as statusline
  'tzachar/local-highlight.nvim',
  config = function()
    require('local-highlight').setup({
      disable_file_types = { 'tex', 'text', 'markdown' },
    })
  end,
  dependencies = { {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
  } },
}
