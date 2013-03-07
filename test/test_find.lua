local lunit = require "lunit"
local tutil = require "utils"
local TEST_CASE, skip = tutil.TEST_CASE, tutil.skip

local path  = require "path"
if not path.IS_WINDOWS then
  local _ENV = TEST_CASE('find')
  test = skip"windows only tests"
  return lunit.run()
end

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

local function make_test(_ENV, opt)

if setfenv then setfenv(1, _ENV) end

local find, wcs, cwd

local function test_f(fn, mask, u, files)
  mask = path.join(cwd, "1", "2", mask)
  if u then mask = wcs.ansitowcs(mask) end
  fn( mask, function(attr)
    local file = attr.cFileName
    if u then file = wcs.wcstoansi(file) end
    local fname = path.basename(file)
    if fname == '.' or fname == '..' then return end
    lunit.assert_true(files[fname])
    files[fname] = nil
  end)
  lunit.assert_nil(next(files))
end

function teardown()
  collectgarbage("collect")collectgarbage("collect") -- force clean lfs.dir
  path.remove(path.join(cwd, '1', '2', '3', 'a1.txt'))
  path.remove(path.join(cwd, '1', '2', '3', 'a2.txt'))
  path.remove(path.join(cwd, '1', '2', '3', 'b1.txt'))
  path.remove(path.join(cwd, '1', '2', '3', 'b2.txt'))
  path.remove(path.join(cwd, '1', '2', 'a1.txt'))
  path.remove(path.join(cwd, '1', '2', 'a2.txt'))
  path.remove(path.join(cwd, '1', '2', 'b1.txt'))
  path.remove(path.join(cwd, '1', '2', 'b2.txt'))
  path.remove(path.join(cwd, '1', '2', '3'))
  path.remove(path.join(cwd, '1', '2'))
  path.remove(path.join(cwd, '1'))
end

function setup()
  cwd  = assert_string(path.currentdir())
  teardown()
  find = require "path.win32.find" .load(opt)
  wcs  = require "path.win32.wcs"  .load(opt)
  mkfile(path.join(cwd, '1', '2', '3', 'a1.txt'))
  mkfile(path.join(cwd, '1', '2', '3', 'a2.txt'))
  mkfile(path.join(cwd, '1', '2', '3', 'b1.txt'))
  mkfile(path.join(cwd, '1', '2', '3', 'b2.txt'))
  mkfile(path.join(cwd, '1', '2', 'a1.txt'))
  mkfile(path.join(cwd, '1', '2', 'a2.txt'))
  mkfile(path.join(cwd, '1', '2', 'b1.txt'))
  mkfile(path.join(cwd, '1', '2', 'b2.txt'))
end

function test_unicode()
  test_f(find.W.findfile, "*", true, {
    ['a1.txt'] = true;
    ['a2.txt'] = true;
    ['b1.txt'] = true;
    ['b2.txt'] = true;
    ['3'     ] = true;
  })

  test_f(find.W.findfile, "*1.txt", true, {
    ['a1.txt'] = true;
    ['b1.txt'] = true;
  })
end

function test_ansi()
  test_f(find.A.findfile, "*", false, {
    ['a1.txt'] = true;
    ['a2.txt'] = true;
    ['b1.txt'] = true;
    ['b2.txt'] = true;
    ['3'     ] = true;
  })

  test_f(find.A.findfile, "*1.txt", false, {
    ['a1.txt'] = true;
    ['b1.txt'] = true;
  })
end

end

local _ENV = TEST_CASE('find ffi')
if not prequire"ffi" then test = skip"ffi module not found" else
  make_test(_M or _ENV, "ffi")
end

local _ENV = TEST_CASE('find alien')
if not prequire"alien" then test = skip"alien module not found" else
  make_test(_M or _ENV, "alien")
end

if not LUNIT_RUN then lunit.run() end