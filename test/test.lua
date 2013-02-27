local lunit = require "lunit"
local path  = require "path"
local findfile = require "path.findfile"

local path_win = path.new('\\')
local path_unx = path.new('/')

local function mkfile(P, data)
  P = path.fullpath(P)
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

local TEST_NAME = 'PATH manipulation' local _ENV = _G
if _VERSION >= 'Lua 5.2' then  _ENV = lunit.module(TEST_NAME,'seeall')
else module( TEST_NAME, package.seeall, lunit.testcase ) end

function test_penlight_1()
  local function testpath(pth,p1,p2,p3)
    local dir,rest = path.splitpath(pth)
    local name,ext = path.splitext(rest)
    assert_equal(dir,p1)
    assert_equal(name,p2)
    assert_equal(ext,p3)
  end

  testpath ([[/bonzo/dog_stuff/cat.txt]],[[/bonzo/dog_stuff]],'cat','.txt')
  testpath ([[/bonzo/dog/cat/fred.stuff]],'/bonzo/dog/cat','fred','.stuff')
  testpath ([[../../alice/jones]],'../../alice','jones','')
  testpath ([[alice]],'','alice','')
  testpath ([[/path-to/dog/]],[[/path-to/dog]],'','')
end

function test_penlight_2()
  local p = path_unx:normolize( '/a/b' )
  assert_equal('/a/b',p)
  assert_equal(p, path_unx:normolize( '/a/fred/../b' ))
  assert_equal(p, path_unx:normolize( '/a//b'        ))
  assert_equal(p, path_unx:normolize( '/a/./b'       ))

  local p = path_win:normolize( '/a/b' )
  assert_equal('\\a\\b',p)
  assert_equal(p, path_win:normolize( '/a/fred/../b' ))
  assert_equal(p, path_win:normolize( '/a//b'        ))
  assert_equal(p, path_win:normolize( '/a/./b'       ))
end

function test_penlight_3()
  if not path.isdir then assert_false('lfs module not found') end
  assert (  path.isdir( "../lua" ))
  assert_false ( path.isfile( "../lua" ))

  assert ( path.isfile( "../lua/path.lua" ) )
  assert_false( path.isdir( "../lua/path.lua" ))
end

function test_system()
  if not path.isdir then assert_false('lfs module not found') end
  if path.IS_WINDOWS then 
    assert_error(function()path_unx:isdir("/any/") end)
    assert_pass (function()path_win:isdir("c:\\")  end)
  else 
    assert_pass (function()path_unx:isdir("/any/") end)
    assert_error(function()path_win:isdir("c:\\")  end)
  end
end

function test_split()
  assert_equal('a', path_unx:root('/a/b/c'))
  assert_equal('', path_unx:root('a/b/c'))

  assert_equal('host', path_win:root('\\\\host\\a\\b\\c'))
  assert_equal('a:',   path_win:root('a:\\b\\c'))
  assert_equal('',     path_win:root('\\b\\c'))
end

function test_norm()
  assert_equal("..\\hello",       path_win:normolize("..\\hello"))
  assert_equal("..\\hello",       path_win:normolize("..\\hello\\world\\.."))
  assert_equal("c:\\hello",       path_win:normolize("c:\\..\\hello"))
  assert_equal("\\hello",         path_win:normolize("\\..\\hello")) -- full path without drive
  assert_equal("\\\\host\\hello", path_win:normolize("\\\\host\\..\\hello"))
  
  assert_equal("/hello",          path_unx:normolize("\\c\\..\\hello"))
  assert_equal("../hello",        path_unx:normolize("..\\hello\\world\\.."))
end

local TEST_NAME = 'PATH system error' local _ENV = _G
if _VERSION >= 'Lua 5.2' then  _ENV = lunit.module(TEST_NAME,'seeall')
else module( TEST_NAME, package.seeall, lunit.testcase ) end

function test()
  local path = path.IS_WINDOWS and path_unx or path_win
  assert_error(function() path.mkdir('./1') end)
  assert_error(function() path.size('./1.txt') end)
end

local TEST_NAME = 'PATH make dir' local _ENV = _G
if _VERSION >= 'Lua 5.2' then  _ENV = lunit.module(TEST_NAME,'seeall')
else module( TEST_NAME, package.seeall, lunit.testcase ) end

local cwd

function teardown()
  path.remove(path.join(cwd, '1', '2', '3', 'test.dat'))
  path.rmdir(path.join(cwd, '1', '2', '3'))
  path.rmdir(path.join(cwd, '1', '2'))
  path.rmdir(path.join(cwd, '1'))
end

function setup()
  cwd = assert_string(path.currentdir())
  teardown()
end

function test_mkdir()
  assert(path.isdir(cwd))
  assert(path.mkdir(path.join(cwd, '1', '2', '3')))
  assert(path.rmdir(path.join(cwd, '1', '2', '3')))
end

function test_clean()
  assert(path.isdir(cwd))
  assert(path.mkdir(path.join(cwd, '1', '2', '3')))
  assert_nil(path.rmdir(path.join(cwd, '1')))
  assert(mkfile(path.join(cwd, '1', '2', '3', 'test.dat')))
  assert_nil(path.rmdir(path.join(cwd, '1', '2', '3')))
  assert(path.remove(path.join(cwd, '1', '2', '3', 'test.dat')))
  assert(path.remove(path.join(cwd, '1', '2', '3')))
  assert_false( path.exists(path.join(cwd, '1', '2', '3')) )
end


local TEST_NAME = 'PATH findfile' local _ENV = _G
if _VERSION >= 'Lua 5.2' then  _ENV = lunit.module(TEST_NAME,'seeall')
else module( TEST_NAME, package.seeall, lunit.testcase ) end

local cwd, files, dirs

function teardown()
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

  params = clone(dirs)
  path.each("./*", "fz", function(f, sz)
    f = up(f)
    assert_not_nil(params[f], "unexpected: " .. f)
    assert_equal(0, sz)
    params[f] = nil
  end, {skipfiles=true, recurse=true})
  assert_nil(next(params))

end

lunit.run()