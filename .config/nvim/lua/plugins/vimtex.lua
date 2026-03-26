return {
  [1] = 'lervag/vimtex',
  lazy = false, --lazy-loading will disable inverse search
  config = function()
    require 'vimtex-setup'
  end,
}
