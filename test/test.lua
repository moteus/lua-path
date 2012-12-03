local lunit = require "lunitx"
local path  = require "path"

local path_win = path.new('\\')
local path_unx = path.new('/')

local TEST_NAME = 'PATH manipulation'
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
