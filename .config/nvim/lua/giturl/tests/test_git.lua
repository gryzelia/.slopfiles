-- Test git helpers: run with nvim --headless -c "lua dofile('.config/nvim/lua/giturl/tests/test_git.lua')" -c "qa"

local git = require('giturl.git')

local pass, fail = 0, 0

local function eq(name, got, expected)
  if type(got) == 'table' and type(expected) == 'table' then
    local match = true
    for k, v in pairs(expected) do
      if got[k] ~= v then
        match = false
        break
      end
    end
    for k, _ in pairs(got) do
      if expected[k] == nil then
        match = false
        break
      end
    end
    if match then
      pass = pass + 1
      return
    end
    fail = fail + 1
    print(('FAIL: %s'):format(name))
    print('  expected:', vim.inspect(expected))
    print('  got:     ', vim.inspect(got))
    return
  end
  if got == expected then
    pass = pass + 1
  else
    fail = fail + 1
    print(('FAIL: %s\n  expected: %s\n  got:      %s'):format(name, tostring(expected), tostring(got)))
  end
end

-- _parse_url: SSH with .git
eq('ssh with .git', git._parse_url('git@github.com:owner/repo.git'), { host = 'github.com', owner = 'owner', repo = 'repo' })

-- _parse_url: HTTPS with .git
eq('https with .git', git._parse_url('https://github.com/owner/repo.git'), { host = 'github.com', owner = 'owner', repo = 'repo' })

-- _parse_url: SSH without .git
eq('ssh without .git', git._parse_url('git@github.com:owner/repo'), { host = 'github.com', owner = 'owner', repo = 'repo' })

-- _parse_url: HTTPS without .git
eq('https without .git', git._parse_url('https://github.com/owner/repo'), { host = 'github.com', owner = 'owner', repo = 'repo' })

-- _parse_url: Nested groups (GitLab style)
eq('nested groups', git._parse_url('git@gitlab.com:group/subgroup/repo.git'), { host = 'gitlab.com', owner = 'group/subgroup', repo = 'repo' })

-- _parse_url: HTTPS nested groups
eq('https nested groups', git._parse_url('https://gitlab.com/group/subgroup/repo.git'), { host = 'gitlab.com', owner = 'group/subgroup', repo = 'repo' })

-- _parse_url: HTTP (not HTTPS)
eq('http url', git._parse_url('http://github.com/owner/repo.git'), { host = 'github.com', owner = 'owner', repo = 'repo' })

-- _parse_url: ssh:// with user
eq('ssh:// with user', git._parse_url('ssh://git@github.com/owner/repo.git'), { host = 'github.com', owner = 'owner', repo = 'repo' })

-- _parse_url: ssh:// without user
eq('ssh:// without user', git._parse_url('ssh://github.com/owner/repo.git'), { host = 'github.com', owner = 'owner', repo = 'repo' })

-- _parse_url: ssh:// nested groups
eq('ssh:// nested groups', git._parse_url('ssh://git@gitlab.com/group/subgroup/repo.git'), { host = 'gitlab.com', owner = 'group/subgroup', repo = 'repo' })

-- _parse_url: SSH alias
eq('ssh alias', git._parse_url('gh:owner/repo.git'), { host = 'gh', owner = 'owner', repo = 'repo' })

-- _parse_url: SSH alias without .git
eq('ssh alias without .git', git._parse_url('gh:owner/repo'), { host = 'gh', owner = 'owner', repo = 'repo' })

-- _parse_url: SSH alias with nested groups
eq('ssh alias nested', git._parse_url('work:group/subgroup/repo.git'), { host = 'work', owner = 'group/subgroup', repo = 'repo' })

-- _parse_url: Invalid URL
local result, err = git._parse_url('not-a-url')
eq('invalid url returns nil', result, nil)
eq('invalid url has error', type(err), 'string')

-- _parse_url: No slash (just host:repo, no owner)
result, err = git._parse_url('git@github.com:repo.git')
eq('no owner returns nil', result, nil)
eq('no owner has error', type(err), 'string')

-- relative_path: basic
eq('relative_path basic', git.relative_path('/home/user/project', '/home/user/project/src/file.lua'), 'src/file.lua')

-- relative_path: file at root
eq('relative_path root file', git.relative_path('/home/user/project', '/home/user/project/file.lua'), 'file.lua')

-- relative_path: outside root returns nil
eq('relative_path outside', git.relative_path('/home/user/project', '/home/other/file.lua'), nil)

-- relative_path: handles trailing slashes
eq('relative_path trailing slash', git.relative_path('/home/user/project/', '/home/user/project/src/file.lua'), 'src/file.lua')

-- _parse_ssh_hostname: resolves alias from ssh -G output
eq('ssh hostname resolution', git._parse_ssh_hostname({
  'user git',
  'hostname github.com',
  'port 22',
  'identityfile ~/.ssh/id_ed25519',
}, 'gh'), 'github.com')

-- _parse_ssh_hostname: fallback when no hostname line
eq('ssh hostname fallback', git._parse_ssh_hostname({
  'user git',
  'port 22',
}, 'gh'), 'gh')

-- _parse_ssh_hostname: empty output
eq('ssh hostname empty', git._parse_ssh_hostname({}, 'myalias'), 'myalias')

-- _parse_ssh_hostname: hostname not on first line
eq('ssh hostname not first', git._parse_ssh_hostname({
  'canonicalizefallbacklocal yes',
  'canonicalizehostname false',
  'user deploy',
  'hostname gitlab.internal.dev',
  'port 2222',
}, 'work'), 'gitlab.internal.dev')

print(('\n%d passed, %d failed'):format(pass, fail))
if fail > 0 then
  os.exit(1)
end
