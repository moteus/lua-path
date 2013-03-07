local lunit = require "lunit"
local tutil = require "utils"
local TEST_CASE, skip = tutil.TEST_CASE, tutil.skip

local path  = require "path"

local path_win = path.new('\\')
local path_unx = path.new('/')

local function mkfile(P, data)
  P = path.fullpath(P)
  path.mkdir(path.dirname(P))
  local f, e = io.open(P, "w+b")
  if not f then return nil, err end
  if data then assert(f:write(data)) end
  f:close()
  return P
end

local function read_file(P)
  local f, err = io.open(P, "rb")
  if not f then return nil, err end
  local data, err = f:read("*all")
  f:close()
  if data then return data end
  return nil, err
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

local _ENV = TEST_CASE('PATH manipulation')

local function testpath(pth,p1,p2,p3)
  local dir,rest = path.splitpath(pth)
  local name,ext = path.splitext(rest)
  assert_equal(dir,p1)
  assert_equal(name,p2)
  assert_equal(ext,p3)
end

function test_penlight_1()
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

function test_splitext()
  testpath ('.log','','','.log')
  testpath ('log','','log','')
  testpath ('.log/','.log','','')
  testpath ('.1001.log','','.1001','.log')
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

local _ENV = TEST_CASE('PATH system error')

function test()
  local path = path.IS_WINDOWS and path_unx or path_win
  assert_error(function() path.mkdir('./1') end)
  assert_error(function() path.size('./1.txt') end)
end

local _ENV = TEST_CASE('PATH make dir')

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

local _ENV = TEST_CASE('PATH findfile')

local cwd, files, dirs

function teardown()
  collectgarbage("collect") -- force clean lfs.dir
  collectgarbage("collect")
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

local _ENV = TEST_CASE('PATH rename')

local cwd

function teardown()
  path.remove(path.join(cwd, '1', 'from.dat'))
  path.remove(path.join(cwd, '1', 'to.dat'  ))
  path.remove(path.join(cwd, '1', 'to.txt'))
  path.remove(path.join(cwd, '1', 'to'))
  path.remove(path.join(cwd, '1'))
end

function setup()
  cwd = assert_string(path.currentdir())
  teardown()
  path.mkdir(path.join(cwd, '1'))
  path.mkdir(path.join(cwd, '1', 'to'))
  mkfile(path.join(cwd, '1', 'from.dat'))
  mkfile(path.join(cwd, '1', 'to.dat'  ))

  assert(path.isfile(path.join(cwd, '1', 'from.dat')))
  assert(path.isfile(path.join(cwd, '1', 'to.dat'  )))
  assert(path.isdir (path.join(cwd, '1', 'to'      )))
end

function test_rename_fail()
  assert_nil( path.rename(
    path.join(cwd, '1', 'from.dat'),
    path.join(cwd, '1', 'to.dat')
  ))
  assert(path.exists(path.join(cwd, '1', 'from.dat')))
  assert(path.exists(path.join(cwd, '1', 'to.dat')))

  assert_nil( path.rename(
    path.join(cwd, '1', 'from.dat'),
    path.join(cwd, '1', 'to')
  ))
  assert(path.exists(path.join(cwd, '1', 'from.dat')))
  assert(path.exists(path.join(cwd, '1', 'to')))

  assert_nil( path.rename(
    path.join(cwd, '1', 'from.txt'),
    path.join(cwd, '1', 'to'),
    true
  ))
  assert(path.exists(path.join(cwd, '1', 'from.dat')))
  assert(path.exists(path.join(cwd, '1', 'to')))
end

function test_rename_pass1()
  assert( path.rename(
    path.join(cwd, '1', 'from.dat'),
    path.join(cwd, '1', 'to.txt')
  ))
  assert_false(path.exists(path.join(cwd, '1', 'from.dat')))
  assert(path.exists(path.join(cwd, '1', 'to.dat')))
end

function test_rename_force_file()
  assert( path.rename(
    path.join(cwd, '1', 'from.dat'),
    path.join(cwd, '1', 'to.dat'),
    true
  ))
  assert_false(path.exists(path.join(cwd, '1', 'from.dat')))
  assert(path.exists(path.join(cwd, '1', 'to.dat')))
end

function test_rename_force_dir()
  assert( path.rename(
    path.join(cwd, '1', 'from.dat'),
    path.join(cwd, '1', 'to'),
    true
  ))
  assert_false(path.exists(path.join(cwd, '1', 'from.dat')))
  assert(path.exists(path.join(cwd, '1', 'to.dat')))
end

local _ENV = TEST_CASE('PATH chdir')

local cwd

function teardown()
  if cwd then path.chdir(cwd) end
  path.rmdir(path.join(cwd, '1', '2'))
  path.rmdir(path.join(cwd, '1'))
end

function setup()
  cwd = path.currentdir()
  path.mkdir(path.join(cwd, '1'))
  path.mkdir(path.join(cwd, '1', '2'))
end

function test_chdir()
  assert(path.isdir('./1'))
  assert_false(path.exists('./2'))
  assert_true(path.chdir('./1'))
  assert_false(path.exists('./1'))
  assert(path.isdir('./2'))
end

local _ENV = TEST_CASE('PATH copy')

local cwd

function teardown()
  collectgarbage("collect") -- force clean lfs.dir
  collectgarbage("collect")
  path.remove(path.join(cwd, '1', 'a1.txt'))
  path.remove(path.join(cwd, '1', 'a2.txt'))
  path.remove(path.join(cwd, '1', 'b1.txt'))
  path.remove(path.join(cwd, '1', 'b2.txt'))
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
  cwd = assert_string(path.currentdir())
  teardown()

  path.mkdir(path.join(cwd, '1'))
  mkfile(path.join(cwd, '1', 'a1.txt'), '12345')
  mkfile(path.join(cwd, '1', 'a2.txt'), '54321')
  mkfile(path.join(cwd, '1', 'b1.txt'), '12345')
  mkfile(path.join(cwd, '1', 'b2.txt'), '54321')
end

function test_copy_fail()
  assert_nil( path.copy(
    path.join(cwd, '1', 'a1.txt'),
    path.join(cwd, '1', 'a2.txt')
  ))
  assert_equal("54321", read_file(path.join(cwd, '1', 'a2.txt')))
end

function test_copy_overwrite()
  assert( path.copy(
    path.join(cwd, '1', 'a1.txt'),
    path.join(cwd, '1', 'a2.txt'),
    {overwrite = true}
  ))
  assert_equal("12345", read_file(path.join(cwd, '1', 'a2.txt')))
end

function test_copy_mkdir()
  assert( path.copy(
    path.join(cwd, '1', 'a1.txt'),
    path.join(cwd, '1', '2', '3', 'a2.txt')
  ))
  assert_equal("12345", read_file(path.join(cwd, '1', '2', '3', 'a2.txt')))
end

function test_copy_batch()
  assert(path.copy(
    path.join(cwd, '1', 'a*.txt'),
    path.join(cwd, '1', '2')
  ))
  assert_equal("12345", read_file(path.join(cwd, '1', '2', 'a1.txt')))
  assert_equal("54321", read_file(path.join(cwd, '1', '2', 'a2.txt')))
  assert_true(path.remove(path.join(cwd, '1', '2', 'a1.txt')))
  assert_true(path.remove(path.join(cwd, '1', '2', 'a2.txt')))

  local fname
  path.each(path.join(cwd, '1', '2', '*'), function(f)
    fname = f
    return true
  end)
  assert_nil(fname)
end

local _ENV = TEST_CASE('PATH clean dir')

local cwd

function teardown()
  local print = print
  print = (path.remove(path.join(cwd, '1', '2', '3', 'b1.txt')))
  print = (path.remove(path.join(cwd, '1', '2', '3', 'b2.txt')))
  print = (path.remove(path.join(cwd, '1', '2', '3', 'b3.txt')))
  print = (path.remove(path.join(cwd, '1', '2', 'a1.txt')))
  print = (path.remove(path.join(cwd, '1', '2', 'a2.txt')))
  print = (path.remove(path.join(cwd, '1', '2', 'a3.txt')))
  print = (path.remove(path.join(cwd, '1', '2', '3')))
  print = (path.remove(path.join(cwd, '1', '2')))
  print = (path.remove(path.join(cwd, '1')))
end

function setup()
  cwd = assert_string(path.currentdir())
  teardown()
  mkfile(path.join(cwd, '1', '2', '3', 'b1.txt'))
  mkfile(path.join(cwd, '1', '2', '3', 'b2.txt'))
  mkfile(path.join(cwd, '1', '2', '3', 'b3.txt'))
  mkfile(path.join(cwd, '1', '2', 'a1.txt'))
  mkfile(path.join(cwd, '1', '2', 'a2.txt'))
  mkfile(path.join(cwd, '1', '2', 'a3.txt'))
end

function test_clean()
  assert_true(path.remove(path.join(cwd, "1", "*"), {recurse=true}))
  assert_false(path.exists(path.join(cwd, "1", "2")))
end

function test_remove()
  assert_string(path.exists(path.join(cwd, "1", "2", "a1.txt")))
  assert_string(path.exists(path.join(cwd, "1", "2", "a2.txt")))
  assert_string(path.exists(path.join(cwd, "1", "2", "a3.txt")))
  assert_string(path.exists(path.join(cwd, "1", "2", "3", "b1.txt")))
  assert_string(path.exists(path.join(cwd, "1", "2", "3", "b2.txt")))
  assert_string(path.exists(path.join(cwd, "1", "2", "3", "b3.txt")))

  assert_true(path.remove(path.join(cwd, "1", "?1.txt"), {recurse=true}))

  assert_false (path.exists(path.join(cwd, "1", "2", "a1.txt")))
  assert_string(path.exists(path.join(cwd, "1", "2", "a2.txt")))
  assert_string(path.exists(path.join(cwd, "1", "2", "a3.txt")))
  assert_false (path.exists(path.join(cwd, "1", "2", "3", "b1.txt")))
  assert_string(path.exists(path.join(cwd, "1", "2", "3", "b2.txt")))
  assert_string(path.exists(path.join(cwd, "1", "2", "3", "b3.txt")))
end

if not LUNIT_RUN then lunit.run() end