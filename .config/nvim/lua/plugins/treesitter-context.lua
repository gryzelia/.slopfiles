return {
  "nvim-treesitter/nvim-treesitter-context",
  config = function()
    require "treesitter-context".setup {
      enable = true,
      multiwindow = true,
      multiline_threshold = 3,
    }
    vim.keymap.set('n', '<leader>tc', ':TSContextToggle<cr>', { desc = 'Toggle [T]reesitter [C]ontext' })
  end,
}
