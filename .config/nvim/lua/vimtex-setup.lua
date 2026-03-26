vim.g.vimtex_delim_list = {
  delim_math = {
    name = {
      { '(', ')' },
      { '[', ']' },
      { '\\{', '\\}' },
      { '\\langle', '\\rangle' },
      { '\\lbrace', '\\rbrace' },
      { '\\lvert', '\\rvert' },
      { '\\lVert', '\\rVert' },
      { '\\lfloor', '\\rfloor' },
      { '\\lceil', '\\rceil' },
      { '\\ulcorner', '\\urcorner' },
      { '\\|', '\\|' }, -- this one doesn't work
      { '\\<', '\\>' },
    },
  },
}

vim.g.vimtex_delim_toggle_mod_list = {
  { '\\left', '\\right' },
  { '\\big', '\\big' },
}

vim.cmd [[
  " filetype plugin indent on
  " syntax enable

  let g:vimtex_view_automatic = 0
  let g:vimtex_indent_on_ampersands = 0

  " automatically push upon :w for latex files
  " augroup auto_git
  " autocmd!
  " autocmd BufWritePost *.bib,*.tex,*.sty silent execute '!git add %' | silent execute '!git commit -m "Auto commit for %"' | silent execute '!git push'
  " autocmd BufRead *.bib,*.tex,*.sty execute '!git pull'
  " augroup END
]]

vim.g.vimtex_compiler_latexmk = {
  ['options'] = {
    '-shell-escape',
    '-file-line-error',
    '-interaction=nonstopmode',
    '-verbose',
  },
}

if vim.loop.os_uname().sysname == 'Linux' then
  vim.g.vimtex_view_general_viewer = 'zathura'
  vim.g.UltiSnipsSnippetDirectories = { '~/.config/nvim/UltiSnips' }
else
  vim.cmd [[
  let g:vimtex_view_general_viewer = 'SumatraPDF'
  let g:vimtex_view_general_options
  \ = '-reuse-instance -forward-search @tex @line @pdf'
  let g:UltiSnipsSnippetDirectories = ['~/AppData/Local/nvim/UltiSnips']
]]
end
