local M = {}

---@class giturl.ProviderDef
---@field hosts? string[]
---@field base_url? string
---@field format fun(params: giturl.FormatParams, config: table): string

---@class giturl.FormatParams
---@field host string
---@field owner string
---@field repo string
---@field ref string
---@field filepath string
---@field line1? number
---@field line2? number

---@type table<string, giturl.ProviderDef>
local providers = {}

-- Built-in providers

providers.github = {
  hosts = { 'github.com' },
  format = function(p, _)
    local url = ('https://%s/%s/%s/blob/%s/%s'):format(p.host, p.owner, p.repo, p.ref, p.filepath)
    if p.line1 then
      url = url .. '#L' .. p.line1
      if p.line2 and p.line2 ~= p.line1 then
        url = url .. '-L' .. p.line2
      end
    end
    return url
  end,
}

providers.gitlab = {
  hosts = { 'gitlab.com' },
  format = function(p, _)
    local url = ('https://%s/%s/%s/-/blob/%s/%s'):format(p.host, p.owner, p.repo, p.ref, p.filepath)
    if p.line1 then
      url = url .. '#L' .. p.line1
      if p.line2 and p.line2 ~= p.line1 then
        url = url .. '-' .. p.line2
      end
    end
    return url
  end,
}

providers.codeberg = {
  hosts = { 'codeberg.org' },
  format = function(p, _)
    local url = ('https://%s/%s/%s/src/branch/%s/%s'):format(p.host, p.owner, p.repo, p.ref, p.filepath)
    if p.line1 then
      url = url .. '#L' .. p.line1
      if p.line2 and p.line2 ~= p.line1 then
        url = url .. '-L' .. p.line2
      end
    end
    return url
  end,
}

providers.sourcegraph = {
  -- No hosts — never auto-detected, must be explicitly selected
  hosts = {},
  base_url = 'https://sourcegraph.com',
  format = function(p, config)
    local base = config.base_url or 'https://sourcegraph.com'
    local url = ('%s/%s/%s/%s@%s/-/blob/%s'):format(base, p.host, p.owner, p.repo, p.ref, p.filepath)
    if p.line1 then
      url = url .. '?L' .. p.line1
      if p.line2 and p.line2 ~= p.line1 then
        url = url .. '-' .. p.line2
      end
    end
    return url
  end,
}

--- Format a URL using a named provider.
---@param name string provider name
---@param params giturl.FormatParams
---@return string|nil url
---@return string|nil err
function M.format(name, params)
  local provider = providers[name]
  if not provider then
    return nil, 'Unknown provider: ' .. name
  end
  return provider.format(params, provider), nil
end

--- Detect provider from a hostname.
---@param host string
---@return string|nil provider name
function M.detect(host)
  for name, provider in pairs(providers) do
    if provider.hosts then
      for _, h in ipairs(provider.hosts) do
        if h == host then
          return name
        end
      end
    end
  end
  return nil
end

--- Register or update a provider.
---@param name string
---@param def giturl.ProviderDef
function M.register(name, def)
  if providers[name] then
    -- Merge: override fields
    for k, v in pairs(def) do
      providers[name][k] = v
    end
  else
    providers[name] = def
  end
end

--- List all provider names.
---@return string[]
function M.list()
  local names = {}
  for name, _ in pairs(providers) do
    table.insert(names, name)
  end
  table.sort(names)
  return names
end

return M
