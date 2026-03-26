return {
  -- Theme inspired by Atom
  'navarasu/onedark.nvim',
  priority = 1000,
  config = function()
    local palette = require('onedark.palette').dark
    local inactive_bg = palette.bg0
    require('onedark').setup({
      colors = {
        bg0 = palette.bg_d,
      },
    })
    vim.cmd.colorscheme 'onedark'

    -- Lighten inactive windows
    vim.api.nvim_set_hl(0, 'InactiveWindow', { bg = inactive_bg })
    vim.api.nvim_set_hl(0, 'InactiveEndOfBuffer', { bg = inactive_bg, fg = inactive_bg })
    vim.api.nvim_create_autocmd({ 'WinEnter', 'BufWinEnter' }, {
      callback = function()
        vim.wo.winhighlight = ''
      end,
    })
    vim.api.nvim_create_autocmd('WinLeave', {
      callback = function()
        vim.wo.winhighlight = 'Normal:InactiveWindow,EndOfBuffer:InactiveEndOfBuffer,SignColumn:InactiveWindow'
      end,
    })
  end,
}
