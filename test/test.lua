local lunit = require "lunit"
local TEST_CASE = lunit.TEST_CASE

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

local _ENV = TEST_CASE('PATH manipulation') if true then

local function testpath(pth,p1,p2,p3)
  local dir,rest = path.splitpath(pth)
  local name,ext = path.splitext(rest)
  assert_equal(p1, dir )
  assert_equal(p2, name)
  assert_equal(p3, ext )
end

function test_penlight_1()
  testpath ([[/bonzo/dog_stuff/cat.txt]],[[/bonzo/dog_stuff]],'cat','.txt')
  testpath ([[/bonzo/dog/cat/fred.stuff]],'/bonzo/dog/cat','fred','.stuff')
  testpath ([[../../alice/jones]],'../../alice','jones','')
  testpath ([[alice]],'','alice','')
  testpath ([[/path-to/dog/]],[[/path-to/dog]],'','')
end

function test_penlight_2()
  local p = path_unx:normalize( '/a/b' )
  assert_equal('/a/b',p)
  assert_equal(p, path_unx:normalize( '/a/fred/../b' ))
  assert_equal(p, path_unx:normalize( '/a//b'        ))
  assert_equal(p, path_unx:normalize( '/a/./b'       ))

  local p = path_win:normalize( '/a/b' )
  assert_equal('\\a\\b',p)
  assert_equal(p, path_win:normalize( '/a/fred/../b' ))
  assert_equal(p, path_win:normalize( '/a//b'        ))
  assert_equal(p, path_win:normalize( '/a/./b'       ))
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
  testpath ('.log','','.log','')
  testpath ('path/.log','path','.log','')
  testpath ('log','','log','')
  testpath ('.log/','.log','','')
  testpath ('.1001.log','','.1001','.log')
  
  local root, ext = path.splitext(".log")
  assert_equal(".log", root)
  assert_equal("", ext)
  assert_equal(ext, path.extension(".log"))

  root, ext = path.splitext("test/.log")
  assert_equal("test/.log", root)
  assert_equal("", ext)
  assert_equal(ext, path.extension("test/.log"))

  root, ext = path.splitext("test/1.log")
  assert_equal("test/1", root)
  assert_equal(".log", ext)
  assert_equal(ext, path.extension("test/1.log"))

  root, ext = path.splitext("test/.1.log")
  assert_equal("test/.1", root)
  assert_equal(".log", ext)
  assert_equal(ext, path.extension("test/.1.log"))
end

function test_splitdrive()
  local a, b
  a,b = path_unx:splitdrive('/root/etc')
  assert_equal('', a) assert_equal('/root/etc', b)

  a,b = path_win:splitdrive('c:\\root\\etc')
  assert_equal('c:', a) assert_equal('root\\etc', b)
end

function test_norm()
  assert_equal("..\\hello",       path_win:normalize("..\\hello"))
  assert_equal("..\\hello",       path_win:normalize("..\\hello\\world\\.."))
  assert_equal("c:\\hello",       path_win:normalize("c:\\..\\hello"))
  assert_equal("c:\\hello",       path_win:normalize("c:\\hello\\."))
  assert_equal("c:\\hello",       path_win:normalize("c:\\hello\\.\\."))
  assert_equal("\\hello",         path_win:normalize("\\..\\hello")) -- full path without drive
  assert_equal("\\\\host\\hello", path_win:normalize("\\\\host\\..\\hello"))
  
  assert_equal("/hello",          path_unx:normalize("\\c\\..\\hello"))
  assert_equal("../hello",        path_unx:normalize("..\\hello\\world\\.."))
  assert_equal("/home/test",      path_unx:normalize("/home/test/."))
  assert_equal("/home/test",      path_unx:normalize("/home/test/./."))
  assert_equal("/home/test/world",path_unx:normalize("/home/test/./world"))
  assert_equal("/home/test",      path_unx:normalize("\\home\\test\\."))
  assert_equal("/",               path_unx:normalize("/"))
  assert_equal("/",               path_unx:normalize("/."))
  assert_equal("/",               path_unx:normalize("/./."))
  assert_equal("/",               path_unx:normalize("/./"))
  assert_equal(".",               path_unx:normalize("././"))
  assert_equal("/dev",            path_unx:normalize("/./dev"))
end

function test_quote()
  assert_equal('c:\\hello', path_win:quote('c:\\hello'))
  assert_equal('"c:\\hello world"', path_win:quote('c:\\hello world'))
  assert_equal('/hello', path_unx:quote('/hello'))
  assert_equal('"/hello world"', path_unx:quote('/hello world'))

  assert_equal('c:\\hello', path_win:unquote('c:\\hello'))
  assert_equal('c:\\hello', path_win:unquote('"c:\\hello"'))
  assert_equal('c:\\"hello"', path_win:unquote('c:\\"hello"'))
  assert_equal('c:\\hello world', path_win:unquote('"c:\\hello world"'))
  assert_equal('c:\\hello world', path_win:unquote('c:\\hello world'))
  assert_equal('/hello', path_unx:unquote('/hello'))
  assert_equal('/hello', path_unx:unquote('"/hello"'))
  assert_equal('/"hello"', path_unx:unquote('/"hello"'))
  assert_equal('/hello world', path_unx:unquote('/hello world'))
  assert_equal('/hello world', path_unx:unquote('"/hello world"'))
end

function test_dir_end()
  assert_equal('c:',              path_win:remove_dir_end('c:\\'))
  assert_equal('c:',              path_win:remove_dir_end('c:\\\\'))
  assert_equal('c:\\.',           path_win:remove_dir_end('c:\\.\\'))
  assert_equal('c:\\',            path_win:ensure_dir_end('c:'))

  assert_equal('',                path_unx:remove_dir_end('/'))
  assert_equal('',                path_unx:remove_dir_end('//'))
  assert_equal('.',               path_unx:remove_dir_end('./'))
  assert_equal('/',               path_unx:ensure_dir_end(''))
  assert_equal('/',               path_unx:ensure_dir_end('/'))
end

function test_join()
  assert_equal("hello",                       path_win:join("hello"))
  assert_equal("hello\\world",                path_win:join("hello", "", "world"))
  assert_equal("c:\\world\\some\\path",       path_win:join("hello", "", "c:\\world", "some", "path"))
  assert_equal("hello\\",                     path_win:join("hello", ""))
end

function test_dot_notation()
  assert_equal("hello\\world",                path_win.join("hello", "", "world"))
  assert_equal("hello/world",                 path_unx.join("hello", "", "world"))
  assert_equal('/',                           path_unx.ensure_dir_end('/'))
  assert_equal('host',                        path_win.root('\\\\host\\a\\b\\c'))
end

end

local _ENV = TEST_CASE('PATH system error') if true then

function test()
  local p = path.IS_WINDOWS and path_unx or path_win
  assert_boolean(path.IS_WINDOWS)
  assert_boolean(p.IS_WINDOWS)
  assert_not_equal(path.IS_WINDOWS, p.IS_WINDOWS)
  assert_error(function() p:mkdir('./1') end)
  assert_error(function() p:size('./1.txt') end)
end

end

local _ENV = TEST_CASE('PATH fullpath')     if true then

function test_user_home()
  local p = assert_string(path.user_home())
  assert_equal(p, path.isdir(p))
  assert_equal(p, path.fullpath("~"))
end

function test_win()
  if path.IS_WINDOWS then
    local p = assert_string(path.currentdir())
    assert_equal(p, path.isdir(p))
    local _, tp = path.splitroot(p)
    assert_equal(p, path.fullpath(path.DIR_SEP .. tp))
  end
end

end

local _ENV = TEST_CASE('PATH make dir')     if true then

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

function test_mkdir_nested()
  local DST = path.join(cwd, '1', '2', '3')
  assert_equal(cwd, path.isdir(cwd))
  assert_string(path.mkdir(DST))
  assert_true  (path.rmdir(DST))
end

function test_mkdir()
  local DST = path.join(cwd, '1')
  assert_equal(cwd, path.isdir(cwd))
  assert_string(path.mkdir(DST))
  assert_true  (path.rmdir(DST))
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

end

local _ENV = TEST_CASE('PATH findfile')     if true then

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
    if math.abs(ts - mt) > 1 then
      assert_equal(ts, mt)
    end
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
  path.each("./*", "fzm", function(f, sz, m)
    f = up(f)
    assert_not_nil(params[f], "unexpected: " .. f)
    assert_equal('directory', m)
    if path.IS_WINDOWS then assert_equal(0, sz) end
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

local _ENV = TEST_CASE('PATH rename')       if true then

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
  assert_nil( path.rename(
    path.join(cwd, '1', 'from.dat'),
    path.join(cwd, '1', 'to'),
    true
  ))
  assert_equal(path.join(cwd, '1', 'from.dat'), path.exists(path.join(cwd, '1', 'from.dat')))
  assert_equal(path.join(cwd, '1', 'to'), path.isdir(path.join(cwd, '1', 'to')))
end

end

local _ENV = TEST_CASE('PATH chdir')        if true then

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

end

local _ENV = TEST_CASE('PATH copy')         if true then

local cwd, files

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

  path.remove(path.join(cwd, '2', 'a1.txt'))
  path.remove(path.join(cwd, '2', 'a2.txt'))
  path.remove(path.join(cwd, '2', 'b1.txt'))
  path.remove(path.join(cwd, '2', 'b2.txt'))
  path.remove(path.join(cwd, '2', '2', 'a1.txt'))
  path.remove(path.join(cwd, '2', '2', 'a2.txt'))
  path.remove(path.join(cwd, '2', '2', 'b1.txt'))
  path.remove(path.join(cwd, '2', '2', 'b2.txt'))
  path.remove(path.join(cwd, '2', '2', '3', 'a1.txt'))
  path.remove(path.join(cwd, '2', '2', '3', 'a2.txt'))
  path.remove(path.join(cwd, '2', '2', '3', 'b1.txt'))
  path.remove(path.join(cwd, '2', '2', '3', 'b2.txt'))

  path.remove(path.join(cwd, '2', '2', '3'))
  path.remove(path.join(cwd, '2', '2' ))
  path.remove(path.join(cwd, '2', 'to'))
  path.remove(path.join(cwd, '2'))
end

function setup()
  cwd = assert_string(path.currentdir())
  teardown()

  path.mkdir(path.join(cwd, '1'))
  path.mkdir(path.join(cwd, '2', 'to'))
  mkfile(path.join(cwd, '1', 'a1.txt'), '12345')
  mkfile(path.join(cwd, '1', 'a2.txt'), '54321')
  mkfile(path.join(cwd, '1', 'b1.txt'), '12345')
  mkfile(path.join(cwd, '1', 'b2.txt'), '54321')

  files = {
    [path.join(cwd, '1', 'a1.txt'):upper()] = true;
    [path.join(cwd, '1', 'a2.txt'):upper()] = true;
    [path.join(cwd, '1', 'b1.txt'):upper()] = true;
    [path.join(cwd, '1', 'b2.txt'):upper()] = true;
  }
end

function test_copy_fail()
  assert_nil( path.copy(
    path.join(cwd, '1', 'a1.txt'),
    path.join(cwd, '1', 'a2.txt')
  ))
  assert_equal("54321", read_file(path.join(cwd, '1', 'a2.txt')))
end

function test_copy_fail_bool()
  assert_nil( path.copy(
    path.join(cwd, '1', 'a1.txt'),
    path.join(cwd, '1', 'a2.txt'),
    false
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

function test_copy_overwrite_dir()
  assert_nil( path.copy(
    path.join(cwd, '1', 'a1.txt'),
    path.join(cwd, '2', 'to'),
    {overwrite = true}
  ))
  assert_equal(path.join(cwd, '2', 'to'), path.isdir(path.join(cwd, '2', 'to')))
end

function test_copy_overwrite_bool()
  assert( path.copy(
    path.join(cwd, '1', 'a1.txt'),
    path.join(cwd, '1', 'a2.txt'),
    true
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

function test_copy_batch_recurse()
  path.mkdir(path.join(cwd, '1'))
  path.mkdir(path.join(cwd, '1', '2'))
  path.mkdir(path.join(cwd, '1', '2', '3'))

  mkfile(path.join(cwd, '1', 'a1.txt'), '12345')
  mkfile(path.join(cwd, '1', 'a2.txt'), '54321')
  mkfile(path.join(cwd, '1', 'b1.txt'), '12345')
  mkfile(path.join(cwd, '1', 'b2.txt'), '54321')

  mkfile(path.join(cwd, '1', '2', '3', 'a1.txt'), '12345')
  mkfile(path.join(cwd, '1', '2', '3', 'a2.txt'), '54321')
  mkfile(path.join(cwd, '1', '2', '3', 'b1.txt'), '12345')
  mkfile(path.join(cwd, '1', '2', '3', 'b2.txt'), '54321')

  assert(path.copy(
    path.join(cwd, '1', 'a*.txt'),
    path.join(cwd, '2'),
    {recurse = true}
  ))

  assert_equal("12345", read_file(path.join(cwd, '2', 'a1.txt')))
  assert_equal("54321", read_file(path.join(cwd, '2', 'a2.txt')))
  assert_equal("12345", read_file(path.join(cwd, '2', '2', '3', 'a1.txt')))
  assert_equal("54321", read_file(path.join(cwd, '2', '2', '3', 'a2.txt')))
end

function test_copy_batch_dir()
  path.mkdir(path.join(cwd, '1'))
  path.mkdir(path.join(cwd, '1', '2'))
  path.mkdir(path.join(cwd, '1', '2', '3'))

  assert(path.copy(
    path.join(cwd, '1', '3*'),
    path.join(cwd, '2'),
    {recurse = true,skipdirs=false}
  ))

  assert_equal(path.join(cwd, '2', '2', '3'), path.isdir(path.join(cwd, '2', '2', '3')))
end

function test_copy_accept()
  local options options = {
    skipdirs = true;
    accept = function(src, des, opt)
      local key = src:upper()
      assert_true(files[key])
      assert_equal(options, opt)
      files[key] = nil;
      return not path.basename(src):find("^b")
    end;
  }
  assert(path.copy(
    path.join(cwd, '1', '*'),
    path.join(cwd, '1', '2'),
    options
  ))
  assert_nil(next(files))

  assert_equal("12345", read_file(path.join(cwd, '1', '2', 'a1.txt')))
  assert_equal("54321", read_file(path.join(cwd, '1', '2', 'a2.txt')))
  assert_false(path.exists(path.join(cwd, '1', '2', '2')))
  assert_false(path.exists(path.join(cwd, '1', '2', 'b1.txt')))
  assert_false(path.exists(path.join(cwd, '1', '2', 'b2.txt')))
end

function test_copy_error_skip()
  local ivalid_path = path.IS_WINDOWS and path.join(cwd, '1*') or "/dev/qaz"
  local options options = {
    error = function(err, src, des, opt)
      local key = src:upper()
      assert_true(files[key])
      assert_equal(options, opt)
      files[key] = nil;
      return true
    end;
  }
  assert(path.copy(
    path.join(cwd, '1', '*'),
    ivalid_path,
    options
  ))
  assert_nil(next(files))
end

function test_copy_error_break()
  local ivalid_path = path.IS_WINDOWS and path.join(cwd, '1*') or "/dev/qaz"
  local flag = false
  assert(path.copy(
    path.join(cwd, '1', '*'),
    ivalid_path,{
    error = function()
      assert_false(flag)
      flag = true
      return false
    end
    }
  ))
  assert_true(flag)
end

end

local _ENV = TEST_CASE('PATH clean dir')    if true then

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
  assert_equal(8, path.remove(path.join(cwd, "1", "*"), {recurse=true}))
  assert_false(path.exists(path.join(cwd, "1", "2")))
end

function test_clean_files()
  assert_equal(6, path.remove(path.join(cwd, "1", "*"), {skipdirs=true;recurse=true}))
  assert(path.exists(path.join(cwd, "1", "2")))
  assert(path.exists(path.join(cwd, "1", "2", "3")))
  assert_false(path.exists(path.join(cwd, "1", "2", "3", "a1.txt")))
end

function test_remove()
  assert_string(path.exists(path.join(cwd, "1", "2", "a1.txt")))
  assert_string(path.exists(path.join(cwd, "1", "2", "a2.txt")))
  assert_string(path.exists(path.join(cwd, "1", "2", "a3.txt")))
  assert_string(path.exists(path.join(cwd, "1", "2", "3", "b1.txt")))
  assert_string(path.exists(path.join(cwd, "1", "2", "3", "b2.txt")))
  assert_string(path.exists(path.join(cwd, "1", "2", "3", "b3.txt")))

  assert_equal(2, path.remove(path.join(cwd, "1", "?1.txt"), {recurse=true}))

  assert_false (path.exists(path.join(cwd, "1", "2", "a1.txt")))
  assert_string(path.exists(path.join(cwd, "1", "2", "a2.txt")))
  assert_string(path.exists(path.join(cwd, "1", "2", "a3.txt")))
  assert_false (path.exists(path.join(cwd, "1", "2", "3", "b1.txt")))
  assert_string(path.exists(path.join(cwd, "1", "2", "3", "b2.txt")))
  assert_string(path.exists(path.join(cwd, "1", "2", "3", "b3.txt")))
end

function test_remove_accept()
  local options options = {
    accept = function(src, opt)
      local key = src:upper()
      assert_equal(options, opt)
      return not not path.basename(src):find("^.[12]")
    end;recurse = true;
  }
  assert_equal(4, path.remove(path.join(cwd, "1", "*"), options))

  assert_false (path.exists(path.join(cwd, "1", "2", "a1.txt")))
  assert_false (path.exists(path.join(cwd, "1", "2", "a2.txt")))
  assert_string(path.exists(path.join(cwd, "1", "2", "a3.txt")))
  assert_false (path.exists(path.join(cwd, "1", "2", "3", "b1.txt")))
  assert_false (path.exists(path.join(cwd, "1", "2", "3", "b2.txt")))
  assert_string(path.exists(path.join(cwd, "1", "2", "3", "b3.txt")))
end

function test_remove_error_skip()
  local n = 0
  assert(path.remove(path.join(cwd, '1', '*'),{
    skipdirs = true; recurse  = true;
    accept = function(src)
      assert(path.remove(src))
      return true
    end;
    error = function(err, src)
      n = n + 1
      return true
    end;
  }))
  assert_equal(6, n)
end

function test_remove_error_break()
  local flag = false
  assert(path.remove(path.join(cwd, '1', '*'),{
    skipdirs = true; recurse  = true;
    accept = function(src)
      assert(path.remove(src))
      return true
    end;
    error = function(err, src)
      assert_false(false)
      flag = true
      return false
    end;
  }))
  assert_true(flag)
end

function test_isempty()
  assert_false( path.isempty(path.join(cwd, "1")) )
  assert_equal(8, path.remove(path.join(cwd, "1", "*"), {recurse=true}))
  assert_equal(path.join(cwd, "1"), path.exists(path.join(cwd, "1")))
  assert_true(path.isempty(path.join(cwd, "1")))
end

end

local _ENV = TEST_CASE('PATH each mask')    if true then

local cwd, J

function teardown()
  path.remove(J(cwd, '1', '2', 'a1.txt'))
  path.remove(J(cwd, '1', '2', 'a2.txt'))
  path.remove(J(cwd, '1', '2', 'a3.txt'))
  path.remove(J(cwd, '1', '2'))
  path.remove(J(cwd, '1'))
end

function setup()
  J = path.join
  cwd = assert_string(path.currentdir())
  teardown()
  mkfile(J(cwd, '1', '2', 'a1.txt'))
  mkfile(J(cwd, '1', '2', 'a2.txt'))
  mkfile(J(cwd, '1', '2', 'a3.txt'))
end

function test_no_mask1()
  local mask = path.ensure_dir_end(J(cwd, '1', '2'))
  local files = {
    [ J(cwd, '1', '2', 'a1.txt') ] = true;
    [ J(cwd, '1', '2', 'a2.txt') ] = true;
    [ J(cwd, '1', '2', 'a3.txt') ] = true;
  }
  path.each(mask, function(f)
    assert_true(files[f], "unexpected: " .. f)
    files[f] = nil
  end)
  assert_nil(next(files))
end

function test_no_mask2()
  local mask = J(cwd, '1', '2')
  local files = {
    [ J(cwd, '1', '2') ] = true;
  }
  path.each(mask, function(f)
    assert_true(files[f], "unexpected: " .. f)
    files[f] = nil
  end)
  assert_nil(next(files))
end

end

if not LUNIT_RUN then lunit.run() end