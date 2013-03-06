local lunit    = require "lunit"
local skip     = function (msg) return function() lunit.fail(msg) end end
local IS_LUA52 = _VERSION >= 'Lua 5.2'
local SEEALL   = IS_LUA52 and 'seeall' or package.seeall
local TCASE    = (not IS_LUA52) and lunit.testcase or nil
local MODULE   = IS_LUA52 and lunit.module or module

local path       = require "path"
local ISW = path.IS_WINDOWS

local function prequire(...)
  local ok, mod = pcall(require, ...)
  if not ok then return nil, mod end
  return mod
end

local function mkfile(P, data)
  P = path.fullpath(P)
  path.mkdir(path.dirname(P))
  local f, e = io.open(P, "w+b")
  if not f then return nil, err end
  if data then assert(f:write(data)) end
  f:close()
  return P
end

local function up(str)
  return path.IS_WINDOWS and str:upper() or str
end

local function clone(t, o)
  o = o or {}
  for k,v in pairs(t) do
    o[ k ] = v
  end
  return o
end

local _ENV = MODULE('each lfs', SEEALL, TCASE)
if not prequire"lfs" then test = skip"lfs module not found" else

local cwd, files, dirs

function teardown()
  collectgarbage("collect") collectgarbage("collect") -- force clean lfs.dir
  path.remove(path.join(cwd, '1', '2', '3', 'test.dat'))
  path.remove(path.join(cwd, '1', '2', '3', 'test.txt'))
  path.remove(path.join(cwd, '1', '2', '3', 'file.dat'))
  path.rmdir(path.join(cwd, '1', '2', '3'))
  path.rmdir(path.join(cwd, '1', '2'))
  path.rmdir(path.join(cwd, '1'))
  path.each = nil
end

function setup()
  cwd = assert_string(path.currentdir())
  teardown()
  path.mkdir(path.join(cwd, '1', '2', '3'))
  mkfile(path.join(cwd, '1', '2', '3', 'test.dat'), '12345')
  mkfile(path.join(cwd, '1', '2', '3', 'test.txt'), '12345')
  mkfile(path.join(cwd, '1', '2', '3', 'file.dat'), '12345')

  local findfile_t = require "path.lfs.find".findfile_t
  path.each = require"path.findfile".load(findfile_t)

  files = {
    [ up(path.join(cwd, '1', '2', '3', 'test.dat')) ] = true;
    [ up(path.join(cwd, '1', '2', '3', 'test.txt')) ] = true;
    [ up(path.join(cwd, '1', '2', '3', 'file.dat')) ] = true;
  }

  dirs = {
    [ up(path.join(cwd, '1', '2', '3')) ] = true;
    [ up(path.join(cwd, '1', '2')) ] = true;
    [ up(path.join(cwd, '1' )) ] = true;
  }
end

function test_cwd()
  assert_equal(cwd, path.fullpath("."))
end

function test_attr()
  for P in pairs(files)do assert(path.exists(P)) end
  for P in pairs(files)do assert(path.isfile(P)) end
  for P in pairs(files)do assert_equal(5, path.size(P)) end

  local ts = os.time()
  path.each("./1/*", function(f)
    assert(path.isfile(f))
    assert(path.touch(f, ts))
  end, {skipdirs=true, recurse=true})

  path.each("./1/*", "ft", function(f,mt)
    assert_equal(ts, mt)
  end, {skipdirs=true, recurse=true})
end

function test_findfile()
  local params

  params = clone(files)
  path.each("./1/2/3/*.*", function(f)
    f = up(f)
    assert_not_nil(params[f], "unexpected: " .. f)
    params[f] = nil
  end)
  assert_nil(next(params))

  params = clone(files)
  for f in path.each("./1/2/3/*.*") do
    f = up(f)
    assert_not_nil(params[f], "unexpected: " .. f)
    params[f] = nil
  end
  assert_nil(next(params))

  params = clone(files)
  params = clone(dirs,params)
  path.each("./1/*", function(f)
    f = up(f)
    assert_not_nil(params[f], "unexpected: " .. f)
    params[f] = nil
  end, {recurse=true})
  assert_equal(up(path.join(cwd, '1' )), next(params))
  assert_nil(next(params, up(path.join(cwd, '1' ))))

  params = clone(files)
  path.each("./1/2/3/*.*", "fz", function(f, sz)
    f = up(f)
    assert_not_nil(params[f], "unexpected: " .. f)
    assert_equal(5, sz)
    params[f] = nil
  end)
  assert_nil(next(params))

  params = clone(files)
  for f, sz in path.each("./1/2/3/*.*", "fz") do
    f = up(f)
    assert_not_nil(params[f], "unexpected: " .. f)
    assert_equal(5, sz)
    params[f] = nil
  end
  assert_nil(next(params))

  params = clone(dirs)
  path.each("./*", "fz", function(f, sz)
    f = up(f)
    assert_not_nil(params[f], "unexpected: " .. f)
    assert_equal(0, sz)
    params[f] = nil
  end, {skipfiles=true, recurse=true})
  assert_nil(next(params))

end

function test_findfile_mask()
  params = clone(files)
  path.each("./1/2/3/t*.*", function(f)
    f = up(f)
    assert_not_nil(params[f], "unexpected: " .. f)
    params[f] = nil
  end)
  assert_not_nil(next(params))
end

function test_findfile_break()
  local flag = false
  path.each("./1/2/3/*.*", function()
    assert_false(flag)
    flag = true
    return 'break'
  end)
  assert_true(flag)
end

end

local _ENV = MODULE('each ffi', SEEALL, TCASE)
if not ISW then test = skip"ffi support only on Windwos" 
elseif not prequire"ffi" then test = skip"ffi module not found" else

local cwd, files, dirs

function teardown()
  collectgarbage("collect") collectgarbage("collect") -- force clean lfs.dir
  path.remove(path.join(cwd, '1', '2', '3', 'test.dat'))
  path.remove(path.join(cwd, '1', '2', '3', 'test.txt'))
  path.remove(path.join(cwd, '1', '2', '3', 'file.dat'))
  path.rmdir(path.join(cwd, '1', '2', '3'))
  path.rmdir(path.join(cwd, '1', '2'))
  path.rmdir(path.join(cwd, '1'))
  path.each = nil
end

function setup()
  cwd = assert_string(path.currentdir())
  teardown()
  path.mkdir(path.join(cwd, '1', '2', '3'))
  mkfile(path.join(cwd, '1', '2', '3', 'test.dat'), '12345')
  mkfile(path.join(cwd, '1', '2', '3', 'test.txt'), '12345')
  mkfile(path.join(cwd, '1', '2', '3', 'file.dat'), '12345')

  local findfile_t = require "path.win32.find".load("ffi").A.findfile_t
  path.each = require"path.findfile".load(findfile_t)

  files = {
    [ up(path.join(cwd, '1', '2', '3', 'test.dat')) ] = true;
    [ up(path.join(cwd, '1', '2', '3', 'test.txt')) ] = true;
    [ up(path.join(cwd, '1', '2', '3', 'file.dat')) ] = true;
  }

  dirs = {
    [ up(path.join(cwd, '1', '2', '3')) ] = true;
    [ up(path.join(cwd, '1', '2')) ] = true;
    [ up(path.join(cwd, '1' )) ] = true;
  }
end

function test_cwd()
  assert_equal(cwd, path.fullpath("."))
end

function test_attr()
  for P in pairs(files)do assert(path.exists(P)) end
  for P in pairs(files)do assert(path.isfile(P)) end
  for P in pairs(files)do assert_equal(5, path.size(P)) end

  local ts = os.time()
  path.each("./1/*", function(f)
    assert(path.isfile(f))
    assert(path.touch(f, ts))
  end, {skipdirs=true, recurse=true})

  path.each("./1/*", "ft", function(f,mt)
    assert_equal(ts, mt)
  end, {skipdirs=true, recurse=true})
end

function test_findfile()
  local params

  params = clone(files)
  path.each("./1/2/3/*.*", function(f)
    f = up(f)
    assert_not_nil(params[f], "unexpected: " .. f)
    params[f] = nil
  end)
  assert_nil(next(params))

  params = clone(files)
  for f in path.each("./1/2/3/*.*") do
    f = up(f)
    assert_not_nil(params[f], "unexpected: " .. f)
    params[f] = nil
  end
  assert_nil(next(params))

  params = clone(files)
  params = clone(dirs,params)
  path.each("./1/*", function(f)
    f = up(f)
    assert_not_nil(params[f], "unexpected: " .. f)
    params[f] = nil
  end, {recurse=true})
  assert_equal(up(path.join(cwd, '1' )), next(params))
  assert_nil(next(params, up(path.join(cwd, '1' ))))

  params = clone(files)
  path.each("./1/2/3/*.*", "fz", function(f, sz)
    f = up(f)
    assert_not_nil(params[f], "unexpected: " .. f)
    assert_equal(5, sz)
    params[f] = nil
  end)
  assert_nil(next(params))

  params = clone(files)
  for f, sz in path.each("./1/2/3/*.*", "fz") do
    f = up(f)
    assert_not_nil(params[f], "unexpected: " .. f)
    assert_equal(5, sz)
    params[f] = nil
  end
  assert_nil(next(params))

  params = clone(dirs)
  path.each("./*", "fz", function(f, sz)
    f = up(f)
    assert_not_nil(params[f], "unexpected: " .. f)
    assert_equal(0, sz)
    params[f] = nil
  end, {skipfiles=true, recurse=true})
  assert_nil(next(params))

end

function test_findfile_mask()
  params = clone(files)
  path.each("./1/2/3/t*.*", function(f)
    f = up(f)
    assert_not_nil(params[f], "unexpected: " .. f)
    params[f] = nil
  end)
  assert_not_nil(next(params))
end

function test_findfile_break()
  local flag = false
  path.each("./1/2/3/*.*", function()
    assert_false(flag)
    flag = true
    return 'break'
  end)
  assert_true(flag)
end

end

local _ENV = MODULE('each alien', SEEALL, TCASE)
if not ISW then test = skip"alien support only on Windwos" 
elseif not prequire"alien" then test = skip"alien module not found" else

local cwd, files, dirs

function teardown()
  collectgarbage("collect") collectgarbage("collect") -- force clean lfs.dir
  path.remove(path.join(cwd, '1', '2', '3', 'test.dat'))
  path.remove(path.join(cwd, '1', '2', '3', 'test.txt'))
  path.remove(path.join(cwd, '1', '2', '3', 'file.dat'))
  path.rmdir(path.join(cwd, '1', '2', '3'))
  path.rmdir(path.join(cwd, '1', '2'))
  path.rmdir(path.join(cwd, '1'))
  path.each = nil
end

function setup()
  cwd = assert_string(path.currentdir())
  teardown()
  path.mkdir(path.join(cwd, '1', '2', '3'))
  mkfile(path.join(cwd, '1', '2', '3', 'test.dat'), '12345')
  mkfile(path.join(cwd, '1', '2', '3', 'test.txt'), '12345')
  mkfile(path.join(cwd, '1', '2', '3', 'file.dat'), '12345')

  local findfile_t = require "path.win32.find".load("alien").A.findfile_t
  path.each = require"path.findfile".load(findfile_t)

  files = {
    [ up(path.join(cwd, '1', '2', '3', 'test.dat')) ] = true;
    [ up(path.join(cwd, '1', '2', '3', 'test.txt')) ] = true;
    [ up(path.join(cwd, '1', '2', '3', 'file.dat')) ] = true;
  }

  dirs = {
    [ up(path.join(cwd, '1', '2', '3')) ] = true;
    [ up(path.join(cwd, '1', '2')) ] = true;
    [ up(path.join(cwd, '1' )) ] = true;
  }
end

function test_cwd()
  assert_equal(cwd, path.fullpath("."))
end

function test_attr()
  for P in pairs(files)do assert(path.exists(P)) end
  for P in pairs(files)do assert(path.isfile(P)) end
  for P in pairs(files)do assert_equal(5, path.size(P)) end

  local ts = os.time()
  path.each("./1/*", function(f)
    assert(path.isfile(f))
    assert(path.touch(f, ts))
  end, {skipdirs=true, recurse=true})

  path.each("./1/*", "ft", function(f,mt)
    assert_equal(ts, mt)
  end, {skipdirs=true, recurse=true})
end

function test_findfile()
  local params

  params = clone(files)
  path.each("./1/2/3/*.*", function(f)
    f = up(f)
    assert_not_nil(params[f], "unexpected: " .. f)
    params[f] = nil
  end)
  assert_nil(next(params))

  params = clone(files)
  for f in path.each("./1/2/3/*.*") do
    f = up(f)
    assert_not_nil(params[f], "unexpected: " .. f)
    params[f] = nil
  end
  assert_nil(next(params))

  params = clone(files)
  params = clone(dirs,params)
  path.each("./1/*", function(f)
    f = up(f)
    assert_not_nil(params[f], "unexpected: " .. f)
    params[f] = nil
  end, {recurse=true})
  assert_equal(up(path.join(cwd, '1' )), next(params))
  assert_nil(next(params, up(path.join(cwd, '1' ))))

  params = clone(files)
  path.each("./1/2/3/*.*", "fz", function(f, sz)
    f = up(f)
    assert_not_nil(params[f], "unexpected: " .. f)
    assert_equal(5, sz)
    params[f] = nil
  end)
  assert_nil(next(params))

  params = clone(files)
  for f, sz in path.each("./1/2/3/*.*", "fz") do
    f = up(f)
    assert_not_nil(params[f], "unexpected: " .. f)
    assert_equal(5, sz)
    params[f] = nil
  end
  assert_nil(next(params))

  params = clone(dirs)
  path.each("./*", "fz", function(f, sz)
    f = up(f)
    assert_not_nil(params[f], "unexpected: " .. f)
    assert_equal(0, sz)
    params[f] = nil
  end, {skipfiles=true, recurse=true})
  assert_nil(next(params))

end

function test_findfile_mask()
  params = clone(files)
  path.each("./1/2/3/t*.*", function(f)
    f = up(f)
    assert_not_nil(params[f], "unexpected: " .. f)
    params[f] = nil
  end)
  assert_not_nil(next(params))
end

function test_findfile_break()
  local flag = false
  path.each("./1/2/3/*.*", function()
    assert_false(flag)
    flag = true
    return 'break'
  end)
  assert_true(flag)
end

end

local _ENV = MODULE('each afx', SEEALL, TCASE)
if not ISW then test = skip"afx support only on Windwos" 
elseif not prequire"afx" then test = skip"afx module not found" else

local cwd, files, dirs

function teardown()
  collectgarbage("collect") collectgarbage("collect") -- force clean lfs.dir
  path.remove(path.join(cwd, '1', '2', '3', 'test.dat'))
  path.remove(path.join(cwd, '1', '2', '3', 'test.txt'))
  path.remove(path.join(cwd, '1', '2', '3', 'file.dat'))
  path.rmdir(path.join(cwd, '1', '2', '3'))
  path.rmdir(path.join(cwd, '1', '2'))
  path.rmdir(path.join(cwd, '1'))
  path.each = nil
end

function setup()
  cwd = assert_string(path.currentdir())
  teardown()
  path.mkdir(path.join(cwd, '1', '2', '3'))
  mkfile(path.join(cwd, '1', '2', '3', 'test.dat'), '12345')
  mkfile(path.join(cwd, '1', '2', '3', 'test.txt'), '12345')
  mkfile(path.join(cwd, '1', '2', '3', 'file.dat'), '12345')

  local findfile_t = require "afx".findfile
  path.each = require"path.findfile".load(findfile_t)

  files = {
    [ up(path.join(cwd, '1', '2', '3', 'test.dat')) ] = true;
    [ up(path.join(cwd, '1', '2', '3', 'test.txt')) ] = true;
    [ up(path.join(cwd, '1', '2', '3', 'file.dat')) ] = true;
  }

  dirs = {
    [ up(path.join(cwd, '1', '2', '3')) ] = true;
    [ up(path.join(cwd, '1', '2')) ] = true;
    [ up(path.join(cwd, '1' )) ] = true;
  }
end

function test_cwd()
  assert_equal(cwd, path.fullpath("."))
end

function test_attr()
  for P in pairs(files)do assert(path.exists(P)) end
  for P in pairs(files)do assert(path.isfile(P)) end
  for P in pairs(files)do assert_equal(5, path.size(P)) end

  local ts = os.time()
  path.each("./1/*", function(f)
    assert(path.isfile(f))
    assert(path.touch(f, ts))
  end, {skipdirs=true, recurse=true})

  path.each("./1/*", "ft", function(f,mt)
    assert_equal(ts, mt)
  end, {skipdirs=true, recurse=true})
end

function test_findfile()
  local params

  params = clone(files)
  path.each("./1/2/3/*.*", function(f)
    f = up(f)
    assert_not_nil(params[f], "unexpected: " .. f)
    params[f] = nil
  end)
  assert_nil(next(params))

  params = clone(files)
  for f in path.each("./1/2/3/*.*") do
    f = up(f)
    assert_not_nil(params[f], "unexpected: " .. f)
    params[f] = nil
  end
  assert_nil(next(params))

  params = clone(files)
  params = clone(dirs,params)
  path.each("./1/*", function(f)
    f = up(f)
    assert_not_nil(params[f], "unexpected: " .. f)
    params[f] = nil
  end, {recurse=true})
  assert_equal(up(path.join(cwd, '1' )), next(params))
  assert_nil(next(params, up(path.join(cwd, '1' ))))

  params = clone(files)
  path.each("./1/2/3/*.*", "fz", function(f, sz)
    f = up(f)
    assert_not_nil(params[f], "unexpected: " .. f)
    assert_equal(5, sz)
    params[f] = nil
  end)
  assert_nil(next(params))

  params = clone(files)
  for f, sz in path.each("./1/2/3/*.*", "fz") do
    f = up(f)
    assert_not_nil(params[f], "unexpected: " .. f)
    assert_equal(5, sz)
    params[f] = nil
  end
  assert_nil(next(params))

  params = clone(dirs)
  path.each("./*", "fz", function(f, sz)
    f = up(f)
    assert_not_nil(params[f], "unexpected: " .. f)
    assert_equal(0, sz)
    params[f] = nil
  end, {skipfiles=true, recurse=true})
  assert_nil(next(params))

end

function test_findfile_mask()
  params = clone(files)
  path.each("./1/2/3/t*.*", function(f)
    f = up(f)
    assert_not_nil(params[f], "unexpected: " .. f)
    params[f] = nil
  end)
  assert_not_nil(next(params))
end

function test_findfile_break()
  local flag = false
  path.each("./1/2/3/*.*", function()
    assert_false(flag)
    flag = true
    return 'break'
  end)
  assert_true(flag)
end

end

lunit.run()