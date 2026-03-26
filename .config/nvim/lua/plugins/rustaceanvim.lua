return {
  'mrcjkb/rustaceanvim',
  ft = { 'rust' },
  version = '^4', -- Recommended
  lazy = false, -- This plugin is already lazy
  dependencies = {
    { 'lvimuser/lsp-inlayhints.nvim' },
  },
  config = function()
    vim.g.rustaceanvim = {
      inlay_hints = {
        highlight = 'NonText',
      },
      tools = {
        hover_actions = {
          auto_focus = true,
        },
      },
      server = {
        on_attach = function()
          vim.lsp.inlay_hint.enable()
        end,
      },
    }
  end,
}
