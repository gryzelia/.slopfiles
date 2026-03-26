return {
  [1] = 'stevearc/oil.nvim',
  version = '^2.15.0',
  ---@modul 'oil'
  ---@type oil.SetupOpts
  opts = {
    default_file_explorer = true,
    columns = {
      'icon',
      'size',
      'mtime',
    },
    delete_to_trash = true,
    view_options = {
      show_hidden = true,
    },
    float = {
      max_width = 120,
      max_height = 80,
    },
  },
  keys = {
    {
      '<C-Bslash>',
      function()
        require('oil').toggle_float()
      end,
    },
  },
  -- Optional dependencies
  dependencies = { { 'echasnovski/mini.icons', opts = {} } },
  -- dependencies = { "nvim-tree/nvim-web-devicons" }, -- use if you prefer nvim-web-devicons
  -- Lazy loading is not recommended because it is very tricky to make it work correctly in all situations.
  lazy = false,
}
