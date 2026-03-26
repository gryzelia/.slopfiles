return {
  'm00qek/baleia.nvim',
  cmd = 'BaleiaOnce',
  keys = {
    { '<leader>ac', '<cmd>BaleiaOnce<cr>', desc = '[A]NSI [C]olorize' },
  },
  config = function()
    local baleia = require('baleia').setup({ name = 'baleia_once' })

    vim.api.nvim_create_user_command('BaleiaOnce', function()
      local buf = vim.api.nvim_get_current_buf()
      baleia.once(buf)
      vim.bo[buf].modified = false
    end, {})
  end,
}
