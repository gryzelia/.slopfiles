return {
  -- Autocompletion
  [1] = 'hrsh7th/nvim-cmp',
  dependencies = {
    'hrsh7th/cmp-buffer',
    'hrsh7th/cmp-cmdline',
    'hrsh7th/cmp-nvim-lsp',
    'hrsh7th/cmp-path',
    'rafamadriz/friendly-snippets',
    {
      'quangnguyen30192/cmp-nvim-ultisnips',
      dependencies = {
        'SirVer/ultisnips',
      },
    },
  },
  config = function()
    require 'cmp-setup'
  end,
}
