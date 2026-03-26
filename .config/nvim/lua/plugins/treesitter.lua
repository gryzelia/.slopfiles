return {
  -- Highlight, edit, and navigate code
  'nvim-treesitter/nvim-treesitter',
  dependencies = {
    'nvim-treesitter/nvim-treesitter-textobjects',
    'nushell/tree-sitter-nu',
  },
  build = ':TSUpdate',
  config = function()
    require 'treesitter-setup'
  end,
}
