local git = require('giturl.git')
local providers = require('giturl.providers')
local buffer = require('giturl.buffer')

local M = {}

---@class giturl.SetupOpts
---@field default_register? string
---@field default_remote? string|fun():string
---@field default_provider? string|fun():string?
---@field keymaps? boolean
---@field providers? table<string, giturl.ProviderDef>

local config = {
  default_register = '+',
  default_remote = 'origin',
  default_provider = nil, -- nil = auto-detect
  keymaps = true,
}

--- Resolve a config value that may be a function.
---@param val any
---@return any
local function resolve(val)
  if type(val) == 'function' then
    return val()
  end
  return val
end

--- Setup giturl with user options.
---@param opts? giturl.SetupOpts
function M.setup(opts)
  opts = opts or {}
  if opts.default_register ~= nil then
    config.default_register = opts.default_register
  end
  if opts.default_remote ~= nil then
    config.default_remote = opts.default_remote
  end
  if opts.default_provider ~= nil then
    config.default_provider = opts.default_provider
  end
  if opts.keymaps ~= nil then
    config.keymaps = opts.keymaps
  end

  -- Register user providers
  if opts.providers then
    for name, def in pairs(opts.providers) do
      providers.register(name, def)
    end
  end

  -- Set keymaps
  if config.keymaps then
    local esc = vim.api.nvim_replace_termcodes('<Esc>', true, false, true)

    local function get_visual_range()
      vim.api.nvim_feedkeys(esc, 'nx', false)
      return vim.fn.line("'<"), vim.fn.line("'>")
    end

    local function map(mode, lhs, fn, desc)
      vim.keymap.set(mode, lhs, fn, { desc = desc })
    end

    -- Copy keymaps: <leader>g{y,Y} = branch ref; <leader>gs{y,Y} = SHA ref
    for _, s in ipairs({ { prefix = '<leader>g', sha = false }, { prefix = '<leader>gs', sha = true } }) do
      local label = s.sha and 'permalink' or 'git URL'

      local function with_sha(o)
        if s.sha then o.convert_to_sha = true end
        return o
      end

      map('n', s.prefix .. 'y', function()
        M.copy_url(with_sha({}))
      end, 'Copy ' .. label .. ' (file)')

      map('n', s.prefix .. 'Y', function()
        M.copy_url(with_sha({ line1 = vim.fn.line('.') }))
      end, 'Copy ' .. label .. ' (current line)')

      map('v', s.prefix .. 'y', function()
        local l1, l2 = get_visual_range()
        M.copy_url(with_sha({ line1 = l1, line2 = l2 }))
      end, 'Copy ' .. label .. ' (line range)')
    end

    -- Picker keymaps (no SHA variant — use <C-l> to drill into commits)
    map('n', '<leader>gp', function()
      M.select_url()
    end, 'Git URL picker (file)')

    map('n', '<leader>gP', function()
      M.select_url({ line1 = vim.fn.line('.') })
    end, 'Git URL picker (current line)')

    map('v', '<leader>gp', function()
      local l1, l2 = get_visual_range()
      M.select_url({ line1 = l1, line2 = l2 })
    end, 'Git URL picker (line range)')
  end
end

---@class giturl.UrlOpts
---@field line1? number
---@field line2? number
---@field ref? string
---@field convert_to_sha? boolean -- if true, use commit SHA as the ref
---@field provider? string
---@field remote? string

--- Generate a URL for the current buffer.
---@param opts? giturl.UrlOpts
---@return string|nil url
---@return string|nil err
function M.get_url(opts)
  opts = opts or {}

  local bufname = vim.api.nvim_buf_get_name(0)
  local parsed, err = buffer.parse(bufname)
  if not parsed then
    return nil, err
  end

  local git_root = parsed.git_root
  local filepath = parsed.filepath

  -- Resolve remote
  local remote = opts.remote or resolve(config.default_remote) or 'origin'

  -- Resolve ref
  local ref = opts.ref or parsed.ref
  if not ref then
    ref = git.get_ref(git_root, remote)
  end
  if opts.convert_to_sha then
    ref = git.get_sha(git_root, ref)
  end

  -- Parse remote URL
  local remote_info, remote_err = git.parse_remote_url(git_root, remote)
  if not remote_info then
    return nil, remote_err
  end

  -- Resolve provider
  local provider_name = opts.provider or resolve(config.default_provider)
  if not provider_name then
    provider_name = providers.detect(remote_info.host)
  end
  if not provider_name then
    return nil, 'Cannot detect provider for host: ' .. remote_info.host .. '. Specify a provider explicitly.'
  end

  -- Format URL
  local params = {
    host = remote_info.host,
    owner = remote_info.owner,
    repo = remote_info.repo,
    ref = ref,
    filepath = filepath,
    line1 = opts.line1,
    line2 = opts.line2,
  }

  return providers.format(provider_name, params)
end

--- Copy a URL to the configured register.
---@param opts? giturl.UrlOpts
function M.copy_url(opts)
  local url, err = M.get_url(opts)
  if not url then
    vim.notify('giturl: ' .. (err or 'unknown error'), vim.log.levels.ERROR)
    return
  end
  vim.fn.setreg(config.default_register, url)
  vim.notify('Copied: ' .. url, vim.log.levels.INFO)
end

--- Interactive picker using Snacks.picker.
---@param opts? giturl.UrlOpts
function M.select_url(opts)
  opts = opts or {}
  local Snacks = require('snacks')

  local bufname = vim.api.nvim_buf_get_name(0)
  local parsed, parse_err = buffer.parse(bufname)
  if not parsed then
    vim.notify('giturl: ' .. (parse_err or 'unknown error'), vim.log.levels.ERROR)
    return
  end
  local git_root = parsed.git_root

  -- Resolve defaults
  local remotes = git.list_remotes(git_root)
  if #remotes == 0 then
    vim.notify('giturl: No remotes found', vim.log.levels.ERROR)
    return
  end

  local state = {
    remote = opts.remote or resolve(config.default_remote) or remotes[1],
    ref = opts.ref or parsed.ref
      or git.get_ref(git_root, resolve(config.default_remote) or remotes[1]),
    provider = opts.provider or nil,
  }

  local function detect_provider()
    local info = git.parse_remote_url(git_root, state.remote)
    return info and providers.detect(info.host) or nil
  end

  if not state.provider then
    state.provider = detect_provider()
  end

  local function do_copy()
    vim.schedule(function()
      M.copy_url(vim.tbl_extend('force', opts, {
        remote = state.remote,
        ref = state.ref,
        convert_to_sha = false,
        provider = state.provider,
      }))
    end)
  end

  -- Sub-picker helper
  ---@param items_list string[]
  ---@param title string
  ---@param on_choice fun(choice: string)
  ---@param on_alt? fun(choice: string) called on <C-l>
  ---@param initial_idx? number 1-based index to focus initially
  local function sub_pick(items_list, title, on_choice, on_alt, initial_idx)
    local actions = {}
    actions.copy_url = function(picker)
      picker:close()
      do_copy()
    end
    if on_alt then
      actions.drill_down = function(picker)
        local item = picker:current()
        picker:close()
        if item then on_alt(item.item) end
      end
    end
    local picker_keys = {
      ['<C-y>'] = { 'copy_url', desc = 'Copy URL', mode = { 'i', 'n' } },
    }
    if on_alt then
      picker_keys['<C-l>'] = { 'drill_down', desc = 'Drill down into commits', mode = { 'i', 'n' } }
    end
    Snacks.picker.pick({
      title = title,
      preview = false,
      layout = { preset = 'select', layout = { width = 0.4, height = 0.3 } },
      items = vim.tbl_map(function(item)
        return { text = item, item = item }
      end, items_list),
      format = function(item) return { { item.text } } end,
      actions = actions,
      on_show = initial_idx and function(picker)
        picker.list:move(initial_idx, true)
      end or nil,
      confirm = function(picker, item)
        picker:close()
        if item then on_choice(item.item) end
      end,
      win = {
        input = { keys = picker_keys },
        list = { keys = picker_keys },
      },
    })
  end

  -- Main menu
  local function show_main()
    local menu = {
      { text = '  Remote:   ' .. state.remote, action = 'remote' },
      { text = '  Ref:      ' .. state.ref, action = 'ref' },
      { text = '  Provider: ' .. (state.provider or '(none)'), action = 'provider' },
    }

    Snacks.picker.pick({
      title = 'Git URL  (<C-y> to copy)',
      preview = false,
      layout = { preset = 'select', layout = { width = 0.5, height = 0.3 } },
      items = vim.tbl_map(function(item)
        return { text = item.text, item = item }
      end, menu),
      format = function(item) return { { item.text } } end,
      actions = {
        copy_url = function(picker)
          picker:close()
          do_copy()
        end,
      },
      win = {
        input = {
          keys = {
            ['<C-y>'] = { 'copy_url', desc = 'Copy URL', mode = { 'i', 'n' } },
          },
        },
        list = {
          keys = {
            ['<C-y>'] = { 'copy_url', desc = 'Copy URL', mode = { 'n' } },
          },
        },
      },
      confirm = function(picker, item)
        if not item then return end
        local action = item.item.action
        picker:close()

        if action == 'remote' then
          local remote_idx
          for i, r in ipairs(remotes) do
            if r == state.remote then remote_idx = i; break end
          end
          sub_pick(remotes, 'Select remote', function(choice)
            state.remote = choice
            state.provider = opts.provider or detect_provider()
            if not opts.ref and not parsed.ref then
              state.ref = git.get_ref(git_root, state.remote)
            end
            show_main()
          end, nil, remote_idx)
        elseif action == 'ref' then
          local function commit_drilldown(ref_name)
            local commits = git.list_commits(git_root, 20, ref_name)
            if #commits == 0 then
              vim.notify('giturl: No commits found for ' .. ref_name, vim.log.levels.WARN)
              show_main()
              return
            end
            local commit_items = {}
            for _, c in ipairs(commits) do
              table.insert(commit_items, c.sha .. ' ' .. c.message)
            end
            sub_pick(commit_items, 'Select commit from ' .. ref_name, function(ci)
              state.ref = ci:match('^(%S+)')
              show_main()
            end)
          end

          local current_ref = git.get_ref(git_root, state.remote)
          local branches = git.list_branches(git_root, state.remote)
          local tags = git.list_tags(git_root)

          -- Build unified ref list: current first (if not a branch/tag), then branches, then tags
          local ref_items = {}
          local branch_set = {}
          for _, b in ipairs(branches) do branch_set[b] = true end
          local tag_set = {}
          for _, t in ipairs(tags) do tag_set[t] = true end

          -- Only show current as a separate entry if it's not already a branch or tag
          if not branch_set[current_ref] and not tag_set[current_ref] then
            table.insert(ref_items, current_ref .. '*')
          end

          for _, b in ipairs(branches) do
            local star = b == current_ref and '*' or ''
            table.insert(ref_items, b .. ' (branch' .. star .. ')')
          end
          for _, t in ipairs(tags) do
            local star = t == current_ref and '*' or ''
            table.insert(ref_items, t .. ' (tag' .. star .. ')')
          end

          -- Find index of currently selected ref
          local ref_idx
          for i, item in ipairs(ref_items) do
            local name = item:gsub('%*$', ''):gsub(' %([^)]+%)$', '')
            if name == state.ref then ref_idx = i; break end
          end

          sub_pick(ref_items, 'Select ref  (<C-l> for commits)', function(choice)
            state.ref = choice:gsub('%*$', ''):gsub(' %([^)]+%)$', '')
            show_main()
          end, function(choice)
            commit_drilldown(choice:gsub('%*$', ''):gsub(' %([^)]+%)$', ''))
          end, ref_idx)
        elseif action == 'provider' then
          local det = detect_provider()
          local all = providers.list()
          local provider_items = {}
          if det then
            table.insert(provider_items, det .. ' (detected)')
          end
          for _, name in ipairs(all) do
            if name ~= det then
              table.insert(provider_items, name)
            end
          end
          local prov_idx
          for i, item in ipairs(provider_items) do
            if item:gsub(' %(detected%)$', '') == state.provider then prov_idx = i; break end
          end
          sub_pick(provider_items, 'Select provider', function(choice)
            state.provider = choice:gsub(' %(detected%)$', '')
            show_main()
          end, nil, prov_idx)
        end
      end,
    })
  end

  show_main()
end

return M
