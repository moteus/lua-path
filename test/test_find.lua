local path  = require "path"
if not path.IS_WINDOWS then return end
local lunit = require "lunit"

local function mkfile(P, data)
  P = path.fullpath(P)
  path.mkdir(path.dirname(P))
  local f, e = io.open(P, "w+b")
  if not f then return nil, err end
  if data then assert(f:write(data)) end
  f:close()
  return P
end

function create_test(wcs, cwd)
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

local _ENV = _G local TEST_NAME = 'find ffi'
if _VERSION >= 'Lua 5.2' then  _ENV = lunit.module(TEST_NAME,'seeall')
else module( TEST_NAME, package.seeall, lunit.testcase ) end

local find, wcs, cwd
local test_f

function teardown()
  collectgarbage("collect") -- force clean lfs.dir
  collectgarbage("collect")
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
  test_f = nil
end

function setup()
  find = require "path.win32.ffi.find"
  wcs  = require "path.win32.ffi.wcs"
  cwd  = assert_string(path.currentdir())
  mkfile(path.join(cwd, '1', '2', '3', 'a1.txt'))
  mkfile(path.join(cwd, '1', '2', '3', 'a2.txt'))
  mkfile(path.join(cwd, '1', '2', '3', 'b1.txt'))
  mkfile(path.join(cwd, '1', '2', '3', 'b2.txt'))
  mkfile(path.join(cwd, '1', '2', 'a1.txt'))
  mkfile(path.join(cwd, '1', '2', 'a2.txt'))
  mkfile(path.join(cwd, '1', '2', 'b1.txt'))
  mkfile(path.join(cwd, '1', '2', 'b2.txt'))
  test_f = create_test(wcs, cwd)
end

function test()
  test_f(find.W.findfile, "*", true, {
    ['a1.txt'] = true;
    ['a2.txt'] = true;
    ['b1.txt'] = true;
    ['b2.txt'] = true;
    ['3'     ] = true;
  })

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

  test_f(find.W.findfile, "*1.txt", true, {
    ['a1.txt'] = true;
    ['b1.txt'] = true;
  })
end

local _ENV = _G local TEST_NAME = 'find alien'
if _VERSION >= 'Lua 5.2' then  _ENV = lunit.module(TEST_NAME,'seeall')
else module( TEST_NAME, package.seeall, lunit.testcase ) end

local find, wcs, cwd
local test_f

function teardown()
  collectgarbage("collect") -- force clean lfs.dir
  collectgarbage("collect")
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
  test_f = nil
end

function setup()
  find = require "path.win32.alien.find"
  wcs  = require "path.win32.alien.wcs"
  cwd  = assert_string(path.currentdir())
  mkfile(path.join(cwd, '1', '2', '3', 'a1.txt'))
  mkfile(path.join(cwd, '1', '2', '3', 'a2.txt'))
  mkfile(path.join(cwd, '1', '2', '3', 'b1.txt'))
  mkfile(path.join(cwd, '1', '2', '3', 'b2.txt'))
  mkfile(path.join(cwd, '1', '2', 'a1.txt'))
  mkfile(path.join(cwd, '1', '2', 'a2.txt'))
  mkfile(path.join(cwd, '1', '2', 'b1.txt'))
  mkfile(path.join(cwd, '1', '2', 'b2.txt'))
  test_f = create_test(wcs, cwd)
end

function test()
  test_f(find.W.findfile, "*", true, {
    ['a1.txt'] = true;
    ['a2.txt'] = true;
    ['b1.txt'] = true;
    ['b2.txt'] = true;
    ['3'     ] = true;
  })

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

  test_f(find.W.findfile, "*1.txt", true, {
    ['a1.txt'] = true;
    ['b1.txt'] = true;
  })
end

lunit.run()
