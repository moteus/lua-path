local lunit    = require "lunit"
local skip     = function (msg) return function() lunit.fail(msg) end end
local IS_LUA52 = _VERSION >= 'Lua 5.2'
local SEEALL   = IS_LUA52 and 'seeall' or package.seeall
local TCASE    = (not IS_LUA52) and lunit.testcase or nil
local MODULE   = IS_LUA52 and lunit.module or module

local path  = require "path"
if not path.IS_WINDOWS then
  local _ENV = MODULE('find', SEEALL, TCASE)
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

local function create_test(wcs, cwd)
  return function(fn, mask, u, files)
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
end

local function init_fs(cwd)
  mkfile(path.join(cwd, '1', '2', '3', 'a1.txt'))
  mkfile(path.join(cwd, '1', '2', '3', 'a2.txt'))
  mkfile(path.join(cwd, '1', '2', '3', 'b1.txt'))
  mkfile(path.join(cwd, '1', '2', '3', 'b2.txt'))
  mkfile(path.join(cwd, '1', '2', 'a1.txt'))
  mkfile(path.join(cwd, '1', '2', 'a2.txt'))
  mkfile(path.join(cwd, '1', '2', 'b1.txt'))
  mkfile(path.join(cwd, '1', '2', 'b2.txt'))
end

local function clean_fs(cwd)
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

local function test_unicode_(find, test_f)
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

local function test_ansi_(find, test_f)
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

local _ENV = MODULE('find ffi', SEEALL, TCASE)
if not prequire"ffi" then test = skip"ffi module not found" else

local find, wcs, cwd, test_f

function teardown()
  test_f = nil
  clean_fs(cwd)
end

function setup()
  find = require "path.win32.find" .load("ffi")
  wcs  = require "path.win32.wcs"  .load("ffi")
  cwd  = assert_string(path.currentdir())
  test_f = create_test(wcs, cwd)
  clean_fs(cwd) init_fs(cwd)
end

function test_unicode() test_unicode_(find, test_f) end

function test_ansi()    test_ansi_(find, test_f)    end

end

local _ENV = MODULE('find alien', SEEALL, TCASE)
if not prequire"alien" then test = skip"alien module not found" else

local find, wcs, cwd, test_f

function teardown()
  test_f = nil
  clean_fs(cwd)
end

function setup()
  find = require "path.win32.find" .load("ffi")
  wcs  = require "path.win32.wcs"  .load("ffi")
  cwd  = assert_string(path.currentdir())
  test_f = create_test(wcs, cwd)
  clean_fs(cwd) init_fs(cwd)
end

function test_unicode() test_unicode_(find, test_f) end

function test_ansi()    test_ansi_(find, test_f)    end

end
lunit.run()
