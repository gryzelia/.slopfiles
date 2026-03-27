-- Test buffer parsing: run with nvim --headless -c "lua dofile('.config/nvim/lua/giturl/tests/test_buffer.lua')" -c "qa"

local buffer = require('giturl.buffer')

local pass, fail = 0, 0

local function eq(name, got, expected)
  if got == expected then
    pass = pass + 1
  else
    fail = fail + 1
    print(('FAIL: %s\n  expected: %s\n  got:      %s'):format(name, tostring(expected), tostring(got)))
  end
end

-- Fugitive with SHA ref
local parsed = buffer.parse('fugitive:///path/to/repo/.git//abc123/src/file.lua')
eq('fugitive git_root', parsed and parsed.git_root, '/path/to/repo')
eq('fugitive ref', parsed and parsed.ref, 'abc123')
eq('fugitive filepath', parsed and parsed.filepath, 'src/file.lua')

-- Fugitive with branch ref
parsed = buffer.parse('fugitive:///repo/.git//main/file.lua')
eq('fugitive branch git_root', parsed and parsed.git_root, '/repo')
eq('fugitive branch ref', parsed and parsed.ref, 'main')
eq('fugitive branch filepath', parsed and parsed.filepath, 'file.lua')

-- Fugitive with nested path
parsed = buffer.parse('fugitive:///home/user/project/.git//feature-branch/src/deep/file.lua')
eq('fugitive nested git_root', parsed and parsed.git_root, '/home/user/project')
eq('fugitive nested ref', parsed and parsed.ref, 'feature-branch')
eq('fugitive nested filepath', parsed and parsed.filepath, 'src/deep/file.lua')

-- Fugitive with long SHA
parsed = buffer.parse('fugitive:///project/.git//a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2/lib/utils.lua')
eq('fugitive sha git_root', parsed and parsed.git_root, '/project')
eq('fugitive sha ref', parsed and parsed.ref, 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2')
eq('fugitive sha filepath', parsed and parsed.filepath, 'lib/utils.lua')

-- Fugitive with worktree path (no .git in URL)
parsed = buffer.parse('fugitive:///home/user/myrepo/worktrees/dev//abc123def456/src/deep/file.lua')
eq('fugitive worktree git_root', parsed and parsed.git_root, '/home/user/myrepo/worktrees/dev')
eq('fugitive worktree ref', parsed and parsed.ref, 'abc123def456')
eq('fugitive worktree filepath', parsed and parsed.filepath, 'src/deep/file.lua')

-- Fugitive with no slash in rest (no parseable ref/filepath split)
local result, err = buffer.parse('fugitive:///repo/.git//file.lua')
eq('fugitive no slash returns nil', result, nil)
eq('fugitive no slash has error', type(err), 'string')

-- Empty buffer
result, err = buffer.parse('')
eq('empty buffer returns nil', result, nil)
eq('empty buffer has error', type(err), 'string')

-- Nil buffer
result, err = buffer.parse(nil)
eq('nil buffer returns nil', result, nil)
eq('nil buffer has error', type(err), 'string')

print(('\n%d passed, %d failed'):format(pass, fail))
if fail > 0 then
  os.exit(1)
end
