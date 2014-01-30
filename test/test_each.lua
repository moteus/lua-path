local lunit = require "lunit"
local TEST_CASE = lunit.TEST_CASE

local SKIP_CASE
if lunit.skip then 
  SKIP_CASE = function(msg) return function() lunit.skip(msg) end end
else
  SKIP_CASE = require "utils".skip
end

local path = require "path"
local ISW  = path.IS_WINDOWS

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

local function make_test(_ENV, opt)

if setfenv then setfenv(1, _ENV) end

local cwd, files, dirs, path_each

function teardown()
  collectgarbage("collect") collectgarbage("collect") -- force clean lfs.dir
  path.remove(path.join(cwd, '1', '2', '3', 'test.dat'))
  path.remove(path.join(cwd, '1', '2', '3', 'test.txt'))
  path.remove(path.join(cwd, '1', '2', '3', 'file.dat'))
  path.rmdir(path.join(cwd, '1', '2', '3'))
  path.rmdir(path.join(cwd, '1', '2'))
  path.rmdir(path.join(cwd, '1'))
end

function setup()
  cwd = assert_string(path.currentdir())
  teardown()
  path.mkdir(path.join(cwd, '1', '2', '3'))
  mkfile(path.join(cwd, '1', '2', '3', 'test.dat'), '12345')
  mkfile(path.join(cwd, '1', '2', '3', 'test.txt'), '12345')
  mkfile(path.join(cwd, '1', '2', '3', 'file.dat'), '12345')

  local findfile_t = assert(opt.get_findfile())
  path_each = require "path.findfile".load(function(opt)
    opt.file = path.fullpath(opt.file)
    return findfile_t(opt)
  end)

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

  local ts = os.time() + 100
  path_each("./1/*", function(f)
    assert(path.isfile(f))
    assert(path.touch(f, ts))
  end, {skipdirs=true, recurse=true})

  path_each("./1/*", "ft", function(f,mt)
    local delta = math.abs(ts - mt)
    assert(delta <= 2)
  end, {skipdirs=true, recurse=true})
end

function test_findfile()
  local params

  params = clone(files)
  path_each("./1/2/3/*.*", function(f)
    f = up(f)
    assert_not_nil(params[f], "unexpected: " .. f)
    params[f] = nil
  end)
  assert_nil(next(params))

  params = clone(files)
  for f in path_each("./1/2/3/*.*") do
    f = up(f)
    assert_not_nil(params[f], "unexpected: " .. f)
    params[f] = nil
  end
  assert_nil(next(params))

  params = clone(files)
  params = clone(dirs,params)
  path_each("./1/*", function(f)
    f = up(f)
    assert_not_nil(params[f], "unexpected: " .. f)
    params[f] = nil
  end, {recurse=true})
  assert_equal(up(path.join(cwd, '1' )), next(params))
  assert_nil(next(params, up(path.join(cwd, '1' ))))

  params = clone(files)
  path_each("./1/2/3/*.*", "fz", function(f, sz)
    f = up(f)
    assert_not_nil(params[f], "unexpected: " .. f)
    assert_equal(5, sz)
    params[f] = nil
  end)
  assert_nil(next(params))

  params = clone(files)
  for f, sz in path_each("./1/2/3/*.*", "fz") do
    f = up(f)
    assert_not_nil(params[f], "unexpected: " .. f)
    assert_equal(5, sz)
    params[f] = nil
  end
  assert_nil(next(params))

  params = clone(dirs)
  path_each("./*", "fzm", function(f, sz, m)
    f = up(f)
    assert_not_nil(params[f], "unexpected: " .. f)
    if ISW then assert_equal(0, sz) end
    assert_equal('directory', m)
    params[f] = nil
  end, {skipfiles=true, recurse=true})
  assert_nil(next(params))

end

function test_findfile_mask()
  params = clone(files)
  path_each("./1/2/3/t*.*", function(f)
    f = up(f)
    assert_not_nil(params[f], "unexpected: " .. f)
    params[f] = nil
  end)
  assert_not_nil(next(params))
end

function test_findfile_break()
  local flag = false
  path_each("./1/2/3/*.*", function()
    assert_false(flag)
    flag = true
    return 'break'
  end)
  assert_true(flag)
end

end

local _ENV = TEST_CASE('each lfs')
if not prequire"lfs" then test = SKIP_CASE"lfs module not found" else
  make_test(_M or _ENV, {
    get_findfile = function() return require "path.lfs.fs".each_impl end;
  })
end

local _ENV = TEST_CASE('each ffi')
if not ISW then test = SKIP_CASE"ffi support only on Windows" 
elseif not prequire"ffi" then test = SKIP_CASE"ffi module not found" else
  make_test(_M or _ENV, {
    get_findfile = function() 
      return require "path.win32.fs".load("ffi", "A").each_impl
    end;
  })
end

local _ENV = TEST_CASE('each alien')
if not ISW then test = SKIP_CASE"alien support only on Windows" 
elseif not prequire"alien" then test = SKIP_CASE"alien module not found" else
  make_test(_M or _ENV, {
    get_findfile = function() 
      return require "path.win32.fs".load("alien", "A").each_impl
    end;
  })
end

local _ENV = TEST_CASE('each syscall')
if ISW then test = SKIP_CASE"syscall support only on non Windows" 
elseif not prequire"path.syscall.fs" then test = SKIP_CASE"syscall module not found" else
  make_test(_M or _ENV, {
    get_findfile = function() return require "path.syscall.fs".each_impl end;
  })
end

if not LUNIT_RUN then lunit.run() end