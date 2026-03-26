return {
  dir = vim.fn.stdpath('config') .. '/lua/giturl',
  config = function()
    require('giturl').setup({})
  end,
}
