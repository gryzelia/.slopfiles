-- Test providers: run with nvim --headless -c "lua dofile('.config/nvim/lua/giturl/tests/test_providers.lua')" -c "qa"

local providers = require('giturl.providers')

local pass, fail = 0, 0

local function eq(name, got, expected)
  if got == expected then
    pass = pass + 1
  else
    fail = fail + 1
    print(('FAIL: %s\n  expected: %s\n  got:      %s'):format(name, tostring(expected), tostring(got)))
  end
end

-- GitHub
eq(
  'github file only',
  providers.format('github', { host = 'github.com', owner = 'user', repo = 'repo', ref = 'main', filepath = 'src/init.lua' }),
  'https://github.com/user/repo/blob/main/src/init.lua'
)
eq(
  'github file+line',
  providers.format('github', { host = 'github.com', owner = 'user', repo = 'repo', ref = 'main', filepath = 'f.lua', line1 = 5 }),
  'https://github.com/user/repo/blob/main/f.lua#L5'
)
eq(
  'github file+range',
  providers.format('github', { host = 'github.com', owner = 'user', repo = 'repo', ref = 'abc123', filepath = 'f.lua', line1 = 5, line2 = 10 }),
  'https://github.com/user/repo/blob/abc123/f.lua#L5-L10'
)
eq(
  'github same line range',
  providers.format('github', { host = 'github.com', owner = 'user', repo = 'repo', ref = 'main', filepath = 'f.lua', line1 = 5, line2 = 5 }),
  'https://github.com/user/repo/blob/main/f.lua#L5'
)
eq(
  'github custom host (GHE)',
  providers.format('github', { host = 'git.corp.com', owner = 'org', repo = 'proj', ref = 'dev', filepath = 'README.md' }),
  'https://git.corp.com/org/proj/blob/dev/README.md'
)
eq(
  'github with SHA ref',
  providers.format('github', { host = 'github.com', owner = 'user', repo = 'repo', ref = 'a1b2c3d4e5f6', filepath = 'f.lua', line1 = 10 }),
  'https://github.com/user/repo/blob/a1b2c3d4e5f6/f.lua#L10'
)

-- GitLab
eq(
  'gitlab file only',
  providers.format('gitlab', { host = 'gitlab.com', owner = 'user', repo = 'repo', ref = 'main', filepath = 'src/init.lua' }),
  'https://gitlab.com/user/repo/-/blob/main/src/init.lua'
)
eq(
  'gitlab file+line',
  providers.format('gitlab', { host = 'gitlab.com', owner = 'user', repo = 'repo', ref = 'main', filepath = 'f.lua', line1 = 5 }),
  'https://gitlab.com/user/repo/-/blob/main/f.lua#L5'
)
eq(
  'gitlab file+range',
  providers.format('gitlab', { host = 'gitlab.com', owner = 'user', repo = 'repo', ref = 'main', filepath = 'f.lua', line1 = 5, line2 = 10 }),
  'https://gitlab.com/user/repo/-/blob/main/f.lua#L5-10'
)
eq(
  'gitlab same line range',
  providers.format('gitlab', { host = 'gitlab.com', owner = 'user', repo = 'repo', ref = 'main', filepath = 'f.lua', line1 = 5, line2 = 5 }),
  'https://gitlab.com/user/repo/-/blob/main/f.lua#L5'
)

-- Codeberg
eq(
  'codeberg file only',
  providers.format('codeberg', { host = 'codeberg.org', owner = 'user', repo = 'repo', ref = 'main', filepath = 'src/init.lua' }),
  'https://codeberg.org/user/repo/src/branch/main/src/init.lua'
)
eq(
  'codeberg file+line',
  providers.format('codeberg', { host = 'codeberg.org', owner = 'user', repo = 'repo', ref = 'main', filepath = 'f.lua', line1 = 5 }),
  'https://codeberg.org/user/repo/src/branch/main/f.lua#L5'
)
eq(
  'codeberg file+range',
  providers.format('codeberg', { host = 'codeberg.org', owner = 'user', repo = 'repo', ref = 'main', filepath = 'f.lua', line1 = 5, line2 = 10 }),
  'https://codeberg.org/user/repo/src/branch/main/f.lua#L5-L10'
)
eq('detect codeberg.org', providers.detect('codeberg.org'), 'codeberg')

-- Sourcegraph
eq(
  'sourcegraph default base_url',
  providers.format('sourcegraph', { host = 'github.com', owner = 'user', repo = 'repo', ref = 'main', filepath = 'f.lua' }),
  'https://sourcegraph.com/github.com/user/repo@main/-/blob/f.lua'
)
eq(
  'sourcegraph single line',
  providers.format('sourcegraph', { host = 'github.com', owner = 'user', repo = 'repo', ref = 'main', filepath = 'f.lua', line1 = 5 }),
  'https://sourcegraph.com/github.com/user/repo@main/-/blob/f.lua?L5'
)
eq(
  'sourcegraph with range',
  providers.format('sourcegraph', { host = 'github.com', owner = 'user', repo = 'repo', ref = 'main', filepath = 'f.lua', line1 = 5, line2 = 10 }),
  'https://sourcegraph.com/github.com/user/repo@main/-/blob/f.lua?L5-10'
)
eq(
  'sourcegraph same line range',
  providers.format('sourcegraph', { host = 'github.com', owner = 'user', repo = 'repo', ref = 'main', filepath = 'f.lua', line1 = 5, line2 = 5 }),
  'https://sourcegraph.com/github.com/user/repo@main/-/blob/f.lua?L5'
)

-- Sourcegraph custom base_url
providers.register('sourcegraph', { base_url = 'https://sg.corp.com' })
eq(
  'sourcegraph custom base_url',
  providers.format('sourcegraph', { host = 'github.com', owner = 'user', repo = 'repo', ref = 'main', filepath = 'f.lua' }),
  'https://sg.corp.com/github.com/user/repo@main/-/blob/f.lua'
)
-- Reset
providers.register('sourcegraph', { base_url = 'https://sourcegraph.com' })

-- detect
eq('detect github.com', providers.detect('github.com'), 'github')
eq('detect gitlab.com', providers.detect('gitlab.com'), 'gitlab')
eq('detect unknown', providers.detect('bitbucket.org'), nil)

-- Unknown provider
local url, err = providers.format('nonexistent', { host = 'x', owner = 'x', repo = 'x', ref = 'x', filepath = 'x' })
eq('unknown provider returns nil', url, nil)
eq('unknown provider has error', type(err), 'string')

-- Custom provider registration
providers.register('gitea', {
  hosts = { 'gitea.myserver.com' },
  format = function(p, _)
    return ('https://%s/%s/%s/src/branch/%s/%s'):format(p.host, p.owner, p.repo, p.ref, p.filepath)
  end,
})
eq(
  'custom provider format',
  providers.format('gitea', { host = 'gitea.myserver.com', owner = 'me', repo = 'proj', ref = 'main', filepath = 'f.lua' }),
  'https://gitea.myserver.com/me/proj/src/branch/main/f.lua'
)
eq('detect custom provider', providers.detect('gitea.myserver.com'), 'gitea')

-- list includes custom
local names = providers.list()
local found_gitea = false
for _, n in ipairs(names) do
  if n == 'gitea' then
    found_gitea = true
  end
end
eq('list includes custom provider', found_gitea, true)

-- list is sorted
local sorted = true
for i = 2, #names do
  if names[i] < names[i - 1] then
    sorted = false
    break
  end
end
eq('list is sorted', sorted, true)

print(('\n%d passed, %d failed'):format(pass, fail))
if fail > 0 then
  os.exit(1)
end
