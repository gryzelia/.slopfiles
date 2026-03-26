return {
  'nvimtools/none-ls.nvim',
  event = 'LspAttach',
  ft = { 'markdown', 'css', 'rust', 'sh', 'bash' },
  dependencies = 'nvim-lua/plenary.nvim',
  config = function()
    require 'none-ls-setup'
  end,
}
