local lunit = require "lunit"
local TEST_CASE = lunit.TEST_CASE

local SKIP_CASE
if lunit.skip then 
  SKIP_CASE = function(msg) return function() lunit.skip(msg) end end
else
  SKIP_CASE = require "utils".skip
end

local IS_WINDOWS = package.config:sub(1,1) == '\\'
local fs, wcs, _T, _t

local function B(str)
  return (str:gsub(".", function(ch)
    return string.format("\\%.03d", ch:byte())
  end))
end

local function Q(str)
  return string.format("%q",str)
end

local function pass_thrue(str) return str end

local function prequire(...)
  local ok, mod = pcall(require, ...)
  if not ok then return nil, mod end
  return mod
end

local function clone(t, o)
  o = o or {}
  for k,v in pairs(t) do
    o[ k ] = v
  end
  return o
end

local function up(str)
  return IS_WINDOWS and str:upper() or str
end

local function ifind(t, f)
  for k, v in ipairs(t) do
    if up(v) == up(f) then
      return k
    end
  end
end

local function CREATE_TEST(name)

local fs, _T, _t = fs, _T, _t
local DIR_SEP = fs.DIR_SEP

local function mkfile(P, data)
  local f, e = io.open(_t(P), "w+b")
  if not f then return nil, e end
  if data then assert(f:write(data)) end
  f:close()
  return P
end

local function read_file(P)
  local f, err = io.open(_t(P), "rb")
  if not f then return nil, err end
  local data, err = f:read("*all")
  f:close()
  if data then return data end
  return nil, err
end

local function J(...)
  return (table.concat({...}, DIR_SEP))
end

local _ENV = TEST_CASE(name .. ": basic")             if true then

local cwd

function setup()
  cwd = assert_string(fs.currentdir())
end

function teardown()
  fs.chdir(cwd)
  fs.rmdir(J(cwd, _T"1"))
end

function test_cwd()
  assert_string(cwd)
  assert_equal(cwd, fs.exists(cwd))
  assert_equal(cwd, fs.isdir(cwd) )
  assert_false(fs.isfile(cwd))
end

function test_md()
  local P = J(cwd, _T"1")
  assert_false(fs.exists(P))
  assert_true (fs.mkdir(P))
  assert_nil  (fs.mkdir(P))
  assert_equal(P, fs.exists(P))
  assert_true (fs.chdir(P))
  assert_equal(P, fs.currentdir())
  assert_true (fs.chdir(cwd))
  assert_equal(cwd, fs.currentdir())
  assert_true (fs.rmdir(P))
  assert_false(fs.exists(P))
end

function test_tmpdir()
  local p = assert_string(fs.tmpdir())
  assert_equal(p, fs.isdir(p))
end

end

local _ENV = TEST_CASE(name .. ": file manipulation") if true then

local cwd, base
local data ="123\r\n456\n789"

function teardown()
  fs.chdir(cwd)
  fs.remove(J(base, _T"test.txt"))
  fs.remove(J(base, _T"test2.txt"))
  fs.rmdir(base)
end

function setup()
  cwd = fs.currentdir()
  base = J(cwd, _T"tmp")

  teardown()
  assert_true(fs.mkdir(base))
  assert(mkfile(J(base, _T"test.txt"), data))
end

function test_remove()
  assert_true(fs.remove(J(base, _T"test.txt")))
  assert_nil(fs.remove(J(base, _T"test.txt")))
end

function test_remove_dir()
  assert_nil(fs.remove(base))
  assert_equal(base, fs.isdir(base))
end

function test_rmdir()
  assert_nil(fs.rmdir(base))
  assert_equal(base, fs.isdir(base))
  assert_true(fs.remove(J(base, _T"test.txt")))
  assert_true(fs.rmdir(base))
end

function test_size()
  assert_equal(#data, fs.size(J(base, _T"test.txt")))
end

function test_touch()
  local SRC = J(base, _T"test.txt")
  local t1 = assert_number(fs.mtime(SRC)) + 100
  assert_true(fs.touch(SRC, t1))
  local t2 = assert_number(fs.mtime(SRC))
  assert(math.abs(t2-t1) <= 2)
  local t2 = assert_number(fs.atime(SRC))
  assert(math.abs(t2-t1) <= 2)
  assert_true(fs.touch(SRC, t1, t1 + 100))
  local t2 = assert_number(fs.mtime(SRC))
  assert(math.abs(t2-(t1+100)) <= 2)
  local t2 = assert_number(fs.atime(SRC))
  assert(math.abs(t2-t1) <= 2)
end

function test_touch_non_exists()
  local SRC = J(base, _T"test2.txt")
  assert_false(fs.exists(SRC))
  assert_nil(fs.touch(SRC))
  assert_false(fs.exists(SRC))
end

end

local _ENV = TEST_CASE(name .. ": copy/move")         if true then

local cwd, base
local data  = "123\r\n456\n789"
local rdata = "789\r\n123\n456"
local tmp   = "tmp"

function teardown()
  fs.chdir(cwd)
  fs.remove(J(base, _T"test.txt"))
  fs.remove(J(base, _T"test2.txt"))
  fs.remove(J(base, _T'nonempty', _T'tmp.dat'))
  fs.remove(J(base, _T'tmp2',     _T'tmp.dat'))
  fs.rmdir(base)

  fs.remove(J(base, _T'from.dat'))
  fs.remove(J(base, _T'to.dat'  ))
  fs.remove(J(base, _T'to.txt'  ))
  fs.remove(J(base, _T'to'      ))
  fs.remove(J(base, _T'tmp2'    ))
  fs.rmdir (J(base, _T'to'      ))
  fs.rmdir (J(base, _T'tmp'     ))
  fs.rmdir (J(base, _T'tmp2'    ))
  fs.rmdir (J(base, _T'nonempty'))
  fs.rmdir (base)
end

function setup()
  cwd = fs.currentdir()
  base = J(cwd, _T(tmp))
  assert_false(fs.exists(base), _t(base) .. " already exists!")

  teardown()
  assert_true(fs.mkdir(base))
  assert_true(fs.mkdir(J(base, _T'to')))
  assert_true(fs.mkdir(J(base, _T'tmp')))
  assert_true(fs.mkdir(J(base, _T'nonempty')))

  assert(mkfile(J(base, _T'from.dat'), data ))
  assert(mkfile(J(base, _T'to.dat'  ), rdata))
  assert(mkfile(J(base, _T'nonempty', _T'tmp.dat'), data ))
end

local function test_fail(operation)
  local SRC, DST = J(base, _T'from.dat'), J(base, _T'to.dat')
  assert_nil(operation(SRC, DST))
  assert_equal(data,  read_file(SRC))
  assert_equal(rdata, read_file(DST))

  assert_nil(operation(SRC, DST, false))
  assert_equal(data,  read_file(SRC))
  assert_equal(rdata, read_file(DST))

  assert_nil(operation(SRC, DST, nil))
  assert_equal(data,  read_file(SRC))
  assert_equal(rdata, read_file(DST))

  SRC, DST = J(base, _T'from.dat'), J(base, _T'to')
  assert_nil(operation(SRC, DST))
  assert_equal(data,  read_file(SRC))
  assert_equal(DST,   fs.isdir(DST) )

  SRC, DST = J(base, _T'unknown.txt'), J(base, _T'to.dat')
  assert_nil(operation(SRC, DST, true))
  assert_false(fs.exists(SRC))
  assert_equal(rdata, read_file(DST))
end

function test_move_fail()
  test_fail(fs.move)
end

function test_copy_fail()
  test_fail(fs.copy)
end

function test_move_pass()
  local SRC, DST = J(base, _T'from.dat'), J(base, _T'to.txt')
  assert_true(fs.move(SRC, DST))
  assert_false(fs.exists(SRC))
  assert_equal(data, read_file(DST))
end

function test_copy_pass()
  local SRC, DST = J(base, _T'from.dat'), J(base, _T'to.txt')
  assert_true(fs.copy(SRC, DST))
  assert_equal(data, read_file(SRC))
  assert_equal(data, read_file(DST))
end

function test_move_force_file()
  local SRC, DST = J(base, _T'from.dat'), J(base, _T'to.dat')
  assert_true( fs.move(SRC, DST, true ))
  assert_false(fs.exists(SRC))
  assert_equal(data, read_file(DST))
end

function test_copy_force_file()
  local SRC, DST = J(base, _T'from.dat'), J(base, _T'to.dat')
  assert_true( fs.copy(SRC, DST, true ))
  assert_equal(data, read_file(SRC))
  assert_equal(data, read_file(DST))
end

function test_move_empty_dir()
  local SRC, DST = J(base, _T'tmp'), J(base, _T'tmp2')
  assert_true( fs.move(SRC, DST) )
  assert_false(fs.exists(SRC))
  assert_equal(DST, fs.isdir(DST))
end

function test_move_nonempty_dir()
  local SRC, DST = J(base, _T'nonempty'), J(base, _T'tmp2')
  assert_true( fs.move(SRC, DST) )
  assert_false(fs.exists(SRC))
  assert_equal(DST, fs.isdir(DST))
end

function test_copy_empty_dir()
  local SRC, DST = J(base, _T'tmp'), J(base, _T'tmp2')
  assert_nil  (fs.copy(SRC, DST))
  assert_false(fs.exists(DST))
end

function test_copy_nonempty_dir()
  local SRC, DST = J(base, _T'nonempty'), J(base, _T'tmp2')
  assert_nil  (fs.copy(SRC, DST))
  assert_false(fs.exists(DST))
end

function test_move_force_dir()
  local SRC, DST = J(base, _T'from.dat'), J(base, _T'to')
  assert_nil( fs.move(SRC, DST, true ) )
  assert_equal(data, read_file(SRC))
  assert_equal(DST, fs.isdir(DST))
end

function test_move_force_dir2()
  local SRC, DST = J(base, _T'tmp'), J(base, _T'to')
  assert_nil( fs.move(SRC, DST, true ))
  assert_equal(SRC, fs.isdir(SRC))
  assert_equal(DST, fs.isdir(DST))
end

function test_copy_force_dir()
  local SRC, DST = J(base, _T'from.dat'), J(base, _T'to')
  assert_nil( fs.copy(SRC, DST, true ))
  assert_equal(data, read_file(SRC))
  assert_equal(DST, fs.isdir(DST))
end

end

local _ENV = TEST_CASE(name .. ": basic iteration")   if true then

local cwd, base
local data = "123\r\n456"
local files

function teardown()
  collectgarbage"collect" -- dir cleanup
  fs.chdir(cwd)
  for _, f in ipairs(files) do
    fs.remove(f)
  end
  fs.rmdir(J(base, _T"1"))
  fs.rmdir(base)
end

function setup()
  cwd = fs.currentdir()
  base = J(cwd, _T"tmp")
  files = {
    J(base, _T"test"),
    J(base, _T"test.txt"),
    J(base, _T"test.dat"),
    J(base, _T"123.test"),
  }
  teardown()
  assert_true(fs.mkdir(base))
  assert_true(fs.mkdir(J(base, _T"1")))
  for _, f in ipairs(files) do
    assert(mkfile(f, data))
  end
end

function test_dir()
  local t = clone(files)
  table.insert(t, J(base, _T"."))
  table.insert(t, J(base, _T".."))
  table.insert(t, J(base, _T"1"))
  local n = 0
  for f in fs.dir(base) do
    assert(ifind(t, J(base, f)), f)
    n = n + 1
  end
  assert_equal(#t, n)
end

function test_dir_not_existing_path()
  local path = J(base, _T"some", _T"nonexists", _T"path")
  if IS_WINDOWS then
    assert_pass(function() fs.dir(path) end)
  else
    skip("LuaFileSystem generate error")
  end
end

function test_each()
  local t = clone(files)
  table.insert(t, J(base, _T"1"))
  local n = 0
  assert_nil(fs.foreach(base .. DIR_SEP, function(f, a)
    assert_string(a.mode)
    assert_number(a.size)
    assert(ifind(t, f), f)
    n = n + 1
  end))
  assert_equal(#t, n)
end

function test_each_impl()
  local t = clone(files)
  table.insert(t, J(base, _T"1"))
  local n = 0
  assert_nil(fs.each_impl{
    file = base .. DIR_SEP,
    callback = function(f, a)
      assert(ifind(t, f), f)
      n = n + 1
    end}
  )
  assert_equal(#t, n)
end

function test_each_impl_generic_for()
  local t = clone(files)
  table.insert(t, J(base, _T"1"))
  local n = 0
  for f in fs.each_impl{file = base .. DIR_SEP} do
    assert(ifind(t, f), f)
    n = n + 1
  end
  assert_equal(#t, n)
end


function test_each_relpath()
  local base = J(_T'.', _T"tmp")
  local t = {
    J(base, _T"1"),
    J(base, _T"test"),
    J(base, _T"test.txt"),
    J(base, _T"test.dat"),
    J(base, _T"123.test"),
  }

  local n = 0
  assert_nil(fs.foreach(base .. DIR_SEP, function(f, a)
    assert_string(a.mode)
    assert_number(a.size)
    assert(ifind(t, f), f)
    n = n + 1
  end))
  assert_equal(#t, n)
end

function test_each_skipdots()
  local t = clone(files)
  table.insert(t, J(base, _T"."))
  table.insert(t, J(base, _T".."))
  table.insert(t, J(base, _T"1"))
  local n = 0
  assert_nil(fs.foreach(base .. DIR_SEP, function(f)
    assert(ifind(t, f), f)
    n = n + 1
  end,{skipdots=false}))
  assert_equal(#t, n)
end

function test_each_skipfiles()
  local t = {}
  table.insert(t, J(base, _T"."))
  table.insert(t, J(base, _T".."))
  table.insert(t, J(base, _T"1"))
  local n = 0
  assert_nil(fs.foreach(base .. DIR_SEP, function(f)
    assert(ifind(t, f), f)
    n = n + 1
  end,{skipdots=false;skipfiles=true}))
  assert_equal(#t, n)
end

function test_each_skipdirs()
  local t = files
  local n = 0
  assert_nil(fs.foreach(base .. DIR_SEP, function(f)
    assert(ifind(t, f), f)
    n = n + 1
  end,{skipdirs=true}))
  assert_equal(#t, n)
end

function test_each_break()
  local n = 0
  assert_equal(123, fs.foreach(base .. DIR_SEP, function(f)
    n = n + 1
    return 123
  end))
  assert_equal(1, n)
end

end

local _ENV = TEST_CASE(name .. ": recurse iteration") if true then

local cwd, base
local data = "123\r\n456"
local files

function teardown()
  collectgarbage"collect" -- dir cleanup
  fs.chdir(cwd)
  for _, f in ipairs(files) do
    fs.remove(f)
  end
  fs.rmdir(J(base, _T"3"))
  fs.rmdir(J(base, _T"2"))
  fs.rmdir(J(base, _T"1"))
  fs.rmdir(base)
end

function setup()
  cwd = fs.currentdir()
  base = J(cwd, _T"tmp")
  files = {
    J(base, _T"test"),
    J(base, _T"test.txt"),
    J(base, _T"test.dat"),
    J(base, _T"123.test"),
    J(base, _T"1", _T"a1.txt"),
    J(base, _T"1", _T"a2.dat"),
    J(base, _T"1", _T"b1.txt"),
    J(base, _T"1", _T"b2.dat"),
    J(base, _T"2", _T"a1.txt"),
    J(base, _T"2", _T"a2.dat"),
    J(base, _T"2", _T"b1.txt"),
    J(base, _T"2", _T"b2.dat"),
  }
  teardown()
  assert_true(fs.mkdir(base))
  assert_true(fs.mkdir(J(base, _T"1")))
  assert_true(fs.mkdir(J(base, _T"2")))
  assert_true(fs.mkdir(J(base, _T"3")))
  for _, f in ipairs(files) do
    -- print(">>> ", Q(f))
    assert(mkfile(f, data))
  end
end

function test_each()
  local t = clone(files)
  table.insert(t, J(base, _T"1"))
  table.insert(t, J(base, _T"2"))
  table.insert(t, J(base, _T"3"))
  local n = 0
  assert_nil(fs.foreach(base .. DIR_SEP, function(f)
    assert(ifind(t, f), f)
    n = n + 1
  end,{recurse=true}))
  assert_equal(#t, n)
end

function test_each_reverse_true()
  local dir  = J(base, _T"1")
  local file = J(dir,  _T"a1.txt")
  assert_true(fs.foreach(base .. DIR_SEP, function(f)
    assert_not_equal(up(dir), up(f))
    return up(file) == up(f)
  end,{recurse=true;reverse=true}))
end

function test_each_reverse_false()
  local dir  = J(base, _T"1")
  local file = J(dir,  _T"a1.txt")
  assert_true(fs.foreach(base .. DIR_SEP, function(f)
    assert_not_equal(up(file), up(f))
    return up(dir) == up(f)
  end,{recurse=true;reverse=false}))
end

function test_each_reverse_nil()
  local dir  = J(base, _T"1")
  local file = J(dir,  _T"a1.txt")
  assert_true(fs.foreach(base .. DIR_SEP, function(f)
    assert_not_equal(up(file), up(f))
    return up(dir) == up(f)
  end,{recurse=true;reverse=nil}))
end

function test_each_skipdots()
  local t = clone(files)
  table.insert(t, J(base, _T"."))
  table.insert(t, J(base, _T".."))
  table.insert(t, J(base, _T"1"))
  table.insert(t, J(base, _T"1", _T"."))
  table.insert(t, J(base, _T"1", _T".."))
  table.insert(t, J(base, _T"2"))
  table.insert(t, J(base, _T"2", _T"."))
  table.insert(t, J(base, _T"2", _T".."))
  table.insert(t, J(base, _T"3"))
  table.insert(t, J(base, _T"3", _T"."))
  table.insert(t, J(base, _T"3", _T".."))
  local n = 0
  assert_nil(fs.foreach(base .. DIR_SEP, function(f)
    assert(ifind(t, f), f)
    n = n + 1
  end,{recurse=true;skipdots=false}))
  assert_equal(#t, n)
end

function test_each_delay()
  local t = clone(files)
  table.insert(t, J(base, _T"1"))
  table.insert(t, J(base, _T"2"))
  table.insert(t, J(base, _T"3"))
  local n = 0
  assert_nil(fs.foreach(base .. DIR_SEP, function(f)
    assert(ifind(t, f), f)
    n = n + 1
  end,{recurse=true;delay=true}))
  assert_equal(#t, n)
end

function test_each_skipdirs()
  local t = files
  local n = 0
  assert_nil(fs.foreach(base .. DIR_SEP, function(f)
    assert(ifind(t, f), _t(f))
    n = n + 1
  end,{recurse=true;skipdirs=true;}))
  assert_equal(#t, n)
end

function test_each_break()
  local n = 0
  assert_equal("break", fs.foreach(base .. DIR_SEP, function(f)
    if up(f) == up( J(base, _T"2", _T"a2.dat") ) then
      n = 1
      return "break"
    end
    n = 0
  end,{recurse=true}))
  assert_equal(1, n)
end

function test_each_break_delay()
  local n = 0
  assert_equal("break", fs.foreach(base .. DIR_SEP, function(f)
    if up(f) == up( J(base, _T"2", _T"a2.dat") ) then
      n = 1
      return "break"
    end
    n = 0
  end,{recurse=true;delay=true;}))
  assert_equal(1, n)
end

function test_each_mask_basename_only()
  local t = {
    J(base, _T"123.test"),
    J(base, _T"1"),
    J(base, _T"1", _T"a1.txt"),
    J(base, _T"1", _T"b1.txt"),
    J(base, _T"2", _T"a1.txt"),
    J(base, _T"2", _T"b1.txt"),
  }
  local n = 0
  assert_nil(fs.foreach(J(base, _T"*1*"), function(f)
    assert(ifind(t, f), f)
    n = n + 1
  end,{recurse=true}))
  assert_equal(#t, n)
end

function test_each_mask_ext()
  local t = {
    J(base, _T"test.dat"),
    J(base, _T"1", _T"a2.dat"),
    J(base, _T"1", _T"b2.dat"),
    J(base, _T"2", _T"a2.dat"),
    J(base, _T"2", _T"b2.dat"),
  }
  local n = 0
  assert_nil(fs.foreach(J(base, _T"*.dat"), function(f)
    assert(ifind(t, f), f)
    n = n + 1
  end,{recurse=true}))
  assert_equal(#t, n)
end

function test_each_attr()
  local F = clone(files)
  table.insert(F, J(base, _T"1"))
  table.insert(F, J(base, _T"2"))
  table.insert(F, J(base, _T"3"))
  local N = 0
  assert_nil(fs.each_impl{
    file=base .. DIR_SEP, recurse=true,
    param = "fpnmaztcl",
    callback = function(f,p,n,m,a,z,t,c,l)
      local attr = assert(fs.attributes(f))
      assert(ifind(F, f), f)
      assert_string(f)
      assert_string(p)
      assert_string(n)
      assert_string(m)
      assert_table(a)
      assert_number(z)
      assert_number(t)
      assert_number(c)
      assert_number(l)
      assert_equal(attr.mode         , m)
      assert_equal(attr.size         , z)
      assert_equal(attr.modification , t)
      assert_equal(attr.change       , c)
      assert_equal(attr.access       , l)
      assert_equal(m, a.mode         )
      assert_equal(z, a.size         )
      assert_equal(t, a.modification )
      assert_equal(c, a.change       )
      assert_equal(l, a.access       )
      N = N + 1
    end,
  })
  assert_equal(#F, N)
end

function test_each_attr_generic_for()
  local F = clone(files)
  table.insert(F, J(base, _T"1"))
  table.insert(F, J(base, _T"2"))
  table.insert(F, J(base, _T"3"))
  local N = 0
  for f,p,n,m,a,z,t,c,l in fs.each_impl{
    file=base .. DIR_SEP, recurse=true,
    param = "fpnmaztcl",
  }do
    local attr = assert(fs.attributes(f))
    assert(ifind(F, f), _t(f))
    assert_string(f)
    assert_string(p)
    assert_string(n)
    assert_string(m)
    assert_table(a)
    assert_number(z)
    assert_number(t)
    assert_number(c)
    assert_number(l)
    assert_equal(attr.mode         , m)
    assert_equal(attr.size         , z)
    assert_equal(attr.modification , t)
    assert_equal(attr.change       , c)
    assert_equal(attr.access       , l)
    assert_equal(m, a.mode         )
    assert_equal(z, a.size         )
    assert_equal(t, a.modification )
    assert_equal(c, a.change       )
    assert_equal(l, a.access       )
    N = N + 1
  end
  assert_equal(#F, N)
end

end

local _ENV = TEST_CASE(name .. ": mask")              if true then

local cwd, base
local data = "123\r\n456"
local files

function teardown()
  collectgarbage"collect" -- dir cleanup
  fs.chdir(cwd)
  for _, f in ipairs(files) do
    fs.remove(f)
  end
  fs.rmdir(base)
end

function setup()
  cwd = fs.currentdir()
  base = J(cwd, _T"tmp")
  files = {
    J(base, _T"test"),
    J(base, _T"test.txt"),
    J(base, _T"test.txtdat"),
    J(base, _T"test.txt.dat"),
  }
  teardown()
  assert_true(fs.mkdir(base))
  for _, f in ipairs(files) do
    assert(mkfile(f, data))
  end
end

function test_ext1()
  local F = clone(files)
  local n = 0
  table.remove(F,1)
  table.remove(F,3)
  fs.foreach(base .. DIR_SEP .. _T"*.txt", function(f)
    assert(ifind(F, f), _t(f))
    n = n + 1
  end)
  assert_equal(#F, n)
end

function test_ext2()
  local F = clone(files)
  local n = 0
  table.remove(F,1)
  table.remove(F,3)
  fs.foreach(base .. DIR_SEP .. _T"test*.txt", function(f)
    assert(ifind(F, f), _t(f))
    n = n + 1
  end)
  assert_equal(#F, n)
end

function test_ext3()
  local F = clone(files)
  local n = 0
  table.remove(F,1)
  table.remove(F,2)
  table.remove(F,2)
  fs.foreach(base .. DIR_SEP .. _T"test?.txt", function(f)
    assert(ifind(F, f), _t(f))
    n = n + 1
  end)
  assert_equal(#F, n)
end

function test_noext()
  local F = clone(files)
  local n = 0
  table.remove(F,2)
  table.remove(F,2)
  table.remove(F,2)
  fs.foreach(base .. DIR_SEP .. _T"test", function(f)
    assert(ifind(F, f), _t(f))
    n = n + 1
  end)
  assert_equal(#F, n)
end

function test_full()
  local F = clone(files)
  local n = 0
  table.remove(F,1)
  table.remove(F,2)
  table.remove(F,2)
  fs.foreach(base .. DIR_SEP .. _T"test.txt", function(f)
    assert(ifind(F, f), _t(f))
    n = n + 1
  end)
  assert_equal(#F, n)
end

end

local _ENV = TEST_CASE(name .. ": mask2")             if true then

local cwd, base
local data = "123\r\n456"
local files

function teardown()
  collectgarbage"collect" -- dir cleanup
  fs.chdir(cwd)
  for _, f in ipairs(files) do
    fs.remove(f)
  end
  fs.rmdir(base)
end

function setup()
  cwd = fs.currentdir()
  base = J(cwd, _T"tmp")
  files = {
    J(base, _T".txt"),
    J(base, _T"1.txt"),
    J(base, _T"1.txtdat"),
    J(base, _T".txtdat"),
    J(base, _T".txt.dat"),
    J(base, _T".dat.txt"),
  }
  teardown()
  assert_true(fs.mkdir(base))
  for _, f in ipairs(files) do
    assert(mkfile(f, data))
  end
end

function test_ext1()
  local F = {
    J(base, _T".txt"),
    J(base, _T"1.txt"),
    J(base, _T"1.txtdat"),
    J(base, _T".dat.txt"),
  }

  fs.foreach(base .. DIR_SEP .. _T"*.txt", function(f)
    local s = (_t(f):sub(-8) == (DIR_SEP .. ".txtdat"))
    if s then skip("FIXME. pat:`*.txt` should not match `.txtdat` but shuld match `1.txtdat` (for windows compat)")
    else table.remove(F,assert_number(ifind(F, f), _t(f))) end
  end)
  local _, str = next(F)
  assert_equal(nil, _t(str))
end

function test_ext2()
  local F = {
    J(base, _T".txt"),
    J(base, _T".txt.dat"),
    J(base, _T".txtdat"),
    J(base, _T"1.txt"),
    J(base, _T"1.txtdat"),
    J(base, _T".dat.txt"),
  }

  fs.foreach(base .. DIR_SEP .. _T"*.txt*", function(f)
    table.remove(F,assert_number(ifind(F, f), _t(f)))
  end)
  local _, str = next(F)
  assert_equal(nil, _t(str))
end

function test_ext3()
  local F = {
    J(base, _T".txt"),
    J(base, _T"1.txt"),
  }
  fs.foreach(base .. DIR_SEP .. _T"?.txt", function(f)
    table.remove(F,assert_number(ifind(F, f), _t(f)))
  end)
  local _, str = next(F)
  assert_equal(nil, _t(str))
end

function test_ext4()
  local F = {
    J(base, _T"1.txt"),
  }
  fs.foreach(base .. DIR_SEP .. _T"1?.txt", function(f)
    table.remove(F,assert_number(ifind(F, f), _t(f)))
  end)
  local _, str = next(F)
  assert_equal(nil, _t(str))
end

function test_ext5()
  local F = {
    J(base, _T"1.txt"),
    J(base, _T"1.txtdat"),
  }
  fs.foreach(base .. DIR_SEP .. _T"1*.txt", function(f)
    table.remove(F,assert_number(ifind(F, f), _t(f)))
  end)
  local _, str = next(F)
  assert_equal(nil, _t(str))
end

function test_ext6()
  local F = {
    J(base, _T".txt"),
    J(base, _T".txt.dat"),
    J(base, _T".txtdat"),
    J(base, _T"1.txt"),
    J(base, _T"1.txtdat"),
    J(base, _T".dat.txt"),
  }

  fs.foreach(base .. DIR_SEP .. _T"*.tx*t", function(f)
    table.remove(F,assert_number(ifind(F, f), _t(f)))
  end)
  local _, str = next(F)
  assert_equal(nil, _t(str))
end

end

local _ENV = TEST_CASE"os test"                       if name == 'lfs' and false then

local cwd, base
local data  = "123\r\n456\n789"
local rdata = "789\r\n123\n456"
local tmp   = "tmp"

function teardown()
  fs.chdir(cwd)
  fs.remove(J(base, _T"test.txt"))
  fs.remove(J(base, _T"test2.txt"))
  fs.remove(J(base, _T'nonempty', _T'tmp.dat'))
  fs.remove(J(base, _T'tmp2',     _T'tmp.dat'))
  fs.rmdir(base)

  fs.remove(J(base, _T'from.dat'))
  fs.remove(J(base, _T'to.dat'  ))
  fs.remove(J(base, _T'to.txt'  ))
  fs.remove(J(base, _T'to'      ))
  fs.rmdir (J(base, _T'to'      ))
  fs.rmdir (J(base, _T'tmp'     ))
  fs.rmdir (J(base, _T'tmp2'    ))
  fs.rmdir (J(base, _T'nonempty'))
  fs.rmdir (base)
end

function setup()
  cwd = fs.currentdir()
  base = J(cwd, _T(tmp))
  assert_false(fs.exists(base), _t(base) .. " already exists!")

  teardown()
  assert_true(fs.mkdir(base))
  assert_true(fs.mkdir(J(base, _T'to')))
  assert_true(fs.mkdir(J(base, _T'tmp')))
  assert_true(fs.mkdir(J(base, _T'nonempty')))

  assert(mkfile(J(base, _T'from.dat'), data ))
  assert(mkfile(J(base, _T'to.dat'  ), rdata))
  assert(mkfile(J(base, _T'nonempty', _T'tmp.dat'), data ))
end

function test_rename_file_to_file()
  local SRC, DST = J(base, _T'from.dat'), J(base, _T'to.dat')
  assert_equal(SRC, fs.isfile(SRC))
  assert_equal(DST, fs.isfile(DST))
  assert_nil(os.rename(SRC, DST))
  assert_equal(SRC, fs.isfile(SRC))
  assert_equal(DST, fs.isfile(DST))
  assert_equal(data,  read_file(SRC))
  assert_equal(rdata, read_file(DST))
end

function test_rename_file_to_dir()
  local SRC, DST = J(base, _T'from.dat'), J(base, _T'to')
  assert_equal(SRC, fs.isfile(SRC))
  assert_equal(DST, fs.isdir(DST))
  assert_nil(os.rename(SRC, DST))
  assert_equal(SRC, fs.isfile(SRC))
  assert_equal(DST, fs.isdir(DST))
end

function test_remove_empty_dir()
  local SRC = J(base, _T'to')
  assert_equal(SRC, fs.isdir(SRC))
  assert_nil(os.remove(SRC))
  assert_equal(SRC, fs.isdir(SRC))
end

function test_remove_nonempty_dir()
  local SRC = J(base, _T'nonempty')
  assert_equal(SRC, fs.isdir(SRC))
  assert_nil(os.remove(SRC))
  assert_equal(SRC, fs.isdir(SRC))
end

end

end -- CREATE_TEST

-------------------------------------------------------------------------------
do -- create tests

if not prequire"lfs" then 
  local _ENV = TEST_CASE("lfs.fs")
  test = SKIP_CASE"lfs module not found"
else
  _T, _t = pass_thrue,pass_thrue
  fs = require"path.lfs.fs"
  CREATE_TEST("lfs")
end

if IS_WINDOWS then
  if not prequire"alien" then 
    local _ENV = TEST_CASE("alien.fs")
    test = SKIP_CASE"alien module not found"
  else
    _T, _t = pass_thrue,pass_thrue
    fs = require"path.win32.fs".load("alien", "A")
    CREATE_TEST("alienA")

    wcs = require"path.win32.wcs".load("alien")
    _T, _t = wcs.ansitowcs, wcs.wcstoansi
    fs  = require"path.win32.fs".load("alien", "W")
    CREATE_TEST("alienW")
  end

  if not prequire"ffi" then 
    local _ENV = TEST_CASE("ffi.fs")
    test = SKIP_CASE"ffi module not found"
  else
    _T, _t = pass_thrue,pass_thrue
    fs = require"path.win32.fs".load("ffi", "A")
    CREATE_TEST("ffiA")

    wcs = require"path.win32.wcs".load("ffi")
    _T, _t = wcs.ansitowcs, wcs.wcstoansi
    fs  = require"path.win32.fs".load("ffi", "W")
    CREATE_TEST("ffiW")
  end
else

  if not prequire"path.syscall.fs" then 
    local _ENV = TEST_CASE("syscall.fs")
    test = SKIP_CASE"syscall module not found"
  else
    _T, _t = pass_thrue,pass_thrue
    fs = require"path.syscall.fs"
    CREATE_TEST("syscall.fs")
  end

end

end
-------------------------------------------------------------------------------

if not LUNIT_RUN then lunit.run() end
