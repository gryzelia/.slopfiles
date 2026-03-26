local fzf = require('fzf-lua')
local utils = require('utils')

fzf.setup({
  keymap = {
    builtin = {
      ['<C-u>'] = 'preview-half-page-up',
      ['<C-d>'] = 'preview-half-page-down',
      ['<C-b>'] = 'preview-page-up',
      ['<C-f>'] = 'preview-page-down',
      ['<S-up>'] = 'preview-top',
      ['<S-down>'] = 'preview-bottom',
    },
    fzf = {
      ['ctrl-h'] = 'half-page-up',
      ['ctrl-l'] = 'half-page-down',
      ['ctrl-q'] = 'select-all+accept',
    },
  },
  winopts = {
    preview = {
      layout = 'horizontal',
      horizontal = 'right:50%',
    }
  },
  lsp = {
    async_or_timeout = true, -- async LSP requests (never block the UI)
  }
})

local function live_grep_git_root()
  local git_root = require('utils').find_git_root()
  if git_root then
    fzf.live_grep({ cwd = git_root })
  end
end

vim.api.nvim_create_user_command('LiveGrepGitRoot', live_grep_git_root, {})

vim.keymap.set('n', '<leader>?', fzf.oldfiles, { desc = '[?] Find recently opened files' })
vim.keymap.set('n', '<leader><space>', fzf.buffers, { desc = '[ ] Find existing buffers' })
vim.keymap.set('n', '<leader>/', function()
  fzf.lgrep_curbuf()
end, { desc = '[/] Fuzzily search in current buffer' })

vim.keymap.set('n', '<leader>s/', function()
  local bufs = vim.tbl_filter(function(b)
    return vim.fn.buflisted(b) == 1 and vim.api.nvim_buf_get_name(b) ~= ''
  end, vim.api.nvim_list_bufs())
  local paths = vim.tbl_map(vim.api.nvim_buf_get_name, bufs)
  if #paths > 0 then
    fzf.live_grep({ search_paths = paths })
  end
end, { desc = '[S]earch [/] in Open Files' })
vim.keymap.set('n', '<leader>ss', fzf.builtin, { desc = '[S]earch [S]elect fzf-lua' })
vim.keymap.set('n', '<leader>gf', fzf.git_files, { desc = 'Search [G]it [F]iles' })
vim.keymap.set('n', '<leader>sf', fzf.files, { desc = '[S]earch [F]iles' })
vim.keymap.set('n', '<leader>sh', fzf.help_tags, { desc = '[S]earch [H]elp' })
vim.keymap.set('n', '<leader>sw', fzf.grep_cword, { desc = '[S]earch current [W]ord' })
vim.keymap.set('n', '<leader>sg', fzf.live_grep, { desc = '[S]earch by [G]rep' })
vim.keymap.set('n', '<leader>sG', ':LiveGrepGitRoot<cr>', { desc = '[S]earch by [G]rep on Git Root' })
vim.keymap.set('n', '<leader>sd', fzf.diagnostics_workspace, { desc = '[S]earch [D]iagnostics' })
vim.keymap.set('n', '<leader>sr', fzf.resume, { desc = '[S]earch [R]esume' })
vim.keymap.set('n', '<leader>sS', function()
  fzf.live_grep({ regex = vim.fn.getreg('/') })
end, { desc = '[S]earch current [S]earch pattern' })
vim.keymap.set('n', '<leader>sq', fzf.quickfix, { desc = '[S]earch [Q]uickfixlist' })

local function prompt_fzf_dir(func, opts)
  local ok, dir = pcall(vim.fn.input, { prompt = 'Directory to search: ', completion = 'dir' })
  if ok then
    if dir ~= '' then
      opts.cwd = dir
    else
      -- take top-level dir of current buffer
      local current_path = vim.fn.expand('%')
      local current_path_rel = utils.relative_to(vim.fn.getcwd(), current_path)
      local top_level_dir = vim.split(current_path_rel, '/')[1]
      opts.cwd = top_level_dir
    end
    func(opts)
  end
end

vim.keymap.set('n', '<leader>spg', function()
  prompt_fzf_dir(fzf.live_grep, {})
end, { desc = '[S]earch in [P]ath by [G]rep' })
vim.keymap.set('n', '<leader>spw', function()
  prompt_fzf_dir(fzf.grep_cword, {})
end, { desc = '[S]earch, in [P]ath, current [W]ord' })
vim.keymap.set('n', '<leader>spS', function()
  prompt_fzf_dir(fzf.live_grep, { regex = vim.fn.getreg('/') })
end, { desc = '[S]earch, in [P]ath, current [S]earch pattern' })
vim.keymap.set('n', '<leader>spf', function()
  prompt_fzf_dir(fzf.files, {})
end, { desc = '[S]earch, in [P]ath, [F]iles' })
vim.keymap.set('n', '<leader>gpf', function()
  prompt_fzf_dir(fzf.git_files, {})
end, { desc = '[G]it [P]ath [F]iles' })

-- Git ref completion for commands
-- Open a floating fish terminal pre-filled with a git command.
-- On Enter, capture the command line and pass args to the callback.
local function prompt_git_in_terminal(subcmd, callback)
  local tmpfile = vim.fn.tempname()
  local fish_init = string.format(
    'function fish_preexec --on-event fish_preexec; echo $argv[1] > %s; exit; end',
    tmpfile
  )
  local buf = vim.api.nvim_create_buf(false, true)
  local width = math.floor(vim.o.columns * 0.8)
  local height = 10
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = 'minimal',
    border = 'rounded',
  })
  vim.fn.termopen('fish -C ' .. vim.fn.shellescape(fish_init))
  vim.api.nvim_create_autocmd('TermClose', {
    buffer = buf,
    once = true,
    callback = function()
      vim.schedule(function()
        pcall(vim.api.nvim_win_close, win, true)
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
        local ok, lines = pcall(vim.fn.readfile, tmpfile)
        vim.fn.delete(tmpfile)
        if ok and #lines > 0 then
          local args = lines[1]:match('^git%s+' .. subcmd .. '%s*(.*)')
          if args then callback(args) end
        end
      end)
    end,
  })
  -- Prefill the command line by sending keystrokes to the terminal
  local chan = vim.bo[buf].channel
  vim.defer_fn(function()
    vim.api.nvim_chan_send(chan, 'git ' .. subcmd .. ' ')
  end, 50)
  vim.cmd('startinsert')
end

-- Git diff helpers
-- opts: { commit = "abc123" } or { from = "A", to = "B" } or {}
local function fzf_diff_exec(opts, actions)
  local git_root = utils.find_git_root()
  local diff_args
  local rev_a, rev_b
  if opts.commit then
    diff_args = opts.commit .. '^!'
    rev_a = opts.commit .. '~1'
    rev_b = opts.commit
  elseif opts.from and opts.to then
    diff_args = opts.from .. '..' .. opts.to
    rev_a = opts.from
    rev_b = opts.to
  elseif opts.ref then
    diff_args = opts.ref
    rev_a = opts.ref
  else
    diff_args = opts.args or ''
  end
  local base_actions = {
    ['default'] = function(selected)
      vim.cmd('edit ' .. vim.fn.fnameescape(git_root .. '/' .. selected[1]))
    end,
    ['ctrl-a'] = {
      fn = function(selected)
        for _, file in ipairs(selected) do
          vim.fn.system('git -C ' .. vim.fn.shellescape(git_root)
            .. ' diff ' .. diff_args .. ' -- ' .. vim.fn.shellescape(file)
            .. ' | git -C ' .. vim.fn.shellescape(git_root) .. ' apply')
        end
      end,
      header = 'apply diff',
    },
    ['ctrl-r'] = {
      fn = function(selected)
        for _, file in ipairs(selected) do
          vim.fn.system('git -C ' .. vim.fn.shellescape(git_root)
            .. ' diff ' .. diff_args .. ' -- ' .. vim.fn.shellescape(file)
            .. ' | git -C ' .. vim.fn.shellescape(git_root) .. ' apply --reverse')
        end
      end,
      header = 'revert diff',
    },
  }
  if rev_a then
    base_actions['ctrl-s'] = {
      fn = function(selected)
        if rev_b then
          vim.cmd('Gedit ' .. rev_b .. ':' .. selected[1])
        else
          vim.cmd('edit ' .. vim.fn.fnameescape(git_root .. '/' .. selected[1]))
        end
        vim.cmd('Gdiffsplit ' .. rev_a)
      end,
      header = 'diffsplit',
    }
  end
  fzf.fzf_exec('git diff --name-only ' .. diff_args, {
    prompt = 'Git Diff(' .. diff_args .. ')> ',
    cwd = git_root,
    fzf_opts = { ['--multi'] = '' },
    preview = 'git diff --color ' .. diff_args .. ' -- {1}',
    actions = vim.tbl_extend('force', base_actions, actions or {}),
  })
end

local function fzf_git_diff_commit(commit)
  local git_root = utils.find_git_root()
  fzf_diff_exec({ commit = commit }, {
    ['ctrl-o'] = {
      fn = function(selected)
        for _, file in ipairs(selected) do
          vim.fn.system('git -C ' .. vim.fn.shellescape(git_root)
            .. ' checkout ' .. commit .. ' -- ' .. vim.fn.shellescape(file))
        end
        fzf_git_diff_commit(commit)
      end,
      header = 'checkout file(s)',
    },
  })
end

local function parse_diff_args(args)
  if not args then
    return {}
  end
  args = args:match('^%s*(.-)%s*$')
  if args == '' then
    return {}
  end
  -- A..B or A...B
  local from, dots, to = args:match('^(%S+)(%.%.%.?)(%S+)$')
  if from and dots == '..' then
    return { from = from, to = to }
  elseif from and dots == '...' then
    return { args = args }
  end
  -- Two space-separated refs (no flags)
  local a, b = args:match('^(%S+)%s+(%S+)$')
  if a and b and not a:match('^%-') and not b:match('^%-') then
    return { from = a, to = b }
  end
  -- Single ref (no flags, no spaces)
  local ref = args:match('^(%S+)$')
  if ref and not ref:match('^%-') then
    return { ref = ref }
  end
  return { args = args }
end

local function fzf_git_diff_range(opts)
  fzf_diff_exec(opts)
end

-- Order two commits so oldest (ancestor) comes first.
-- Returns oldest, newest or nil if neither is an ancestor of the other.
local function order_commits(a, b)
  if vim.fn.system('git merge-base --is-ancestor ' .. a .. ' ' .. b):match('') ~= nil
    and vim.v.shell_error == 0 then
    return a, b
  elseif vim.fn.system('git merge-base --is-ancestor ' .. b .. ' ' .. a):match('') ~= nil
    and vim.v.shell_error == 0 then
    return b, a
  end
  return nil, nil
end

-- Check if selected commits form a continuous range in the log.
local function is_continuous_range(oldest, newest, count)
  local result = vim.fn.systemlist('git rev-list --count ' .. oldest .. '~1..' .. newest)
  return tonumber(result[1]) == count
end

-- Git log with args (like :Git log in fugitive)
local function fzf_git_log(args, warning)
  local log_cmd = 'git log --oneline --color --decorate ' .. (args or '')
  local prompt = warning
    and ('\x1b[31m' .. warning .. '\x1b[0m > ')
    or 'Git Log> '
  fzf.git_commits({
    cmd = log_cmd,
    prompt = prompt,
    fzf_opts = { ['--no-multi'] = false, ['--multi'] = '' },
    actions = {
      ['ctrl-o'] = {
        fn = function(selected)
          if #selected == 1 then
            local commit = selected[1]:match('[a-f0-9]+')
            if commit then
              fzf_git_diff_commit(commit)
            end
          else
            local a = selected[1]:match('[a-f0-9]+')
            local b = selected[#selected]:match('[a-f0-9]+')
            local oldest, newest = order_commits(a, b)
            -- note: assumes monotonicity of the commit range
            if not oldest or not is_continuous_range(oldest, newest, #selected) then
              fzf_git_log(args, 'Selection is not a continuous range')
              return
            end
            fzf_git_diff_range({ from = oldest .. '~1', to = newest })
          end
        end,
        header = 'search diff',
      },
      ['ctrl-f'] = {
        fn = function(selected)
          local commit = selected[1]:match('[a-f0-9]+')
          if commit then
            vim.cmd('Gedit ' .. commit)
          end
        end,
        header = 'view in fugitive',
      },
    },
  })
end

vim.keymap.set('n', '<leader>gl', function()
  prompt_git_in_terminal('log', fzf_git_log)
end, { desc = '[G]it [L]og' })

vim.keymap.set('n', '<leader>gd', function()
  prompt_git_in_terminal('diff', function(args)
    fzf_git_diff_range(parse_diff_args(args))
  end)
end, { desc = '[G]it [D]iff' })

vim.keymap.set('n', '<leader>gh', function()
  fzf.git_hunks()
end, { desc = '[G]it [H]unks' })

vim.keymap.set('n', '<leader>gr', function()
  prompt_git_in_terminal('reflog', function(args)
    fzf.git_commits({
      cmd = 'git reflog --color --decorate ' .. (args or ''),
      preview = 'git show --color {1}',
      actions = {
        ['ctrl-o'] = {
          fn = function(selected)
            local commit = selected[1]:match('[a-f0-9]+')
            if commit then
              fzf_git_diff_commit(commit)
            end
          end,
          header = 'search diff',
        },
        ['ctrl-f'] = {
          fn = function(selected)
            local commit = selected[1]:match('[a-f0-9]+')
            if commit then
              vim.cmd('Gedit ' .. commit)
            end
          end,
          header = 'view in fugitive',
        },
      },
    })
  end)
end, { desc = '[G]it [R]eflog' })

vim.keymap.set('n', '<leader>gb', fzf.git_branches, { desc = '[G]it [B]ranches' })
vim.keymap.set('n', '<leader>gt', fzf.git_tags, { desc = '[G]it [T]ags' })

-- vim: ts=2 sts=2 sw=2 et
