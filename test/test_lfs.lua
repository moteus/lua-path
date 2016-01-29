#!/usr/bin/env lua5.1

local IS_WINDOWS = package.config:sub(1,1) == '\\'

local function prequire(...)
  local ok, mod = pcall(require, ...)
  if not ok then return nil, mod end
  return mod
end

local function test(name, lfs)

local nonexists = "/8f00e678b1984de4a49d7650e1534327"
local sep = string.match (package.config, "[^\n]+")
local upper = ".."

print (name)

io.write(".")
io.flush()

function attrdir (path)
        for file in lfs.dir(path) do
                if file ~= "." and file ~= ".." then
                        local f = path..sep..file
                        print ("\t=> "..f.." <=")
                        local attr = lfs.attributes (f)
                        assert (type(attr) == "table")
                        if attr.mode == "directory" then
                                attrdir (f)
                        else
                                for name, value in pairs(attr) do
                                        print (name, value)
                                end
                        end
                end
        end
end

-- Checking changing directories
local current = assert (lfs.currentdir())
local reldir = string.gsub (current, "^.*%"..sep.."([^"..sep.."])$", "%1")
assert (lfs.chdir (upper), "could not change to upper directory")
assert (lfs.chdir (reldir), "could not change back to current directory")
assert (lfs.currentdir() == current, "error trying to change directories")
assert (lfs.chdir ("this couldn't be an actual directory") == nil, "could change to a non-existent directory")

io.write(".")
io.flush()

-- Changing creating and removing directories
local tmpdir = current..sep.."lfs_tmp_dir"
local tmpfile = tmpdir..sep.."tmp_file"

-- Test for existence of a previous lfs_tmp_dir
-- that may have resulted from an interrupted test execution and remove it
if lfs.chdir (tmpdir) then
    assert (lfs.chdir (upper), "could not change to upper directory")
    assert (os.remove (tmpfile), "could not remove file from previous test")
    assert (lfs.rmdir (tmpdir), "could not remove directory from previous test")
end

io.write(".")
io.flush()

-- tries to create a directory
assert (lfs.mkdir (tmpdir), "could not make a new directory")
local attrib, errmsg = lfs.attributes (tmpdir)
if not attrib then
        error ("could not get attributes of file `"..tmpdir.."':\n"..errmsg)
end
local f = io.open(tmpfile, "w")
f:close()

io.write(".")
io.flush()

-- Change access time
local testdate = os.time({ year = 2007, day = 10, month = 2, hour=0})
assert (lfs.touch (tmpfile, testdate))
local new_att = assert (lfs.attributes (tmpfile))
assert (math.abs(new_att.access - testdate) <= 1, "could not set access time")
assert (math.abs(new_att.modification - testdate) <= 1, "could not set modification time")

io.write(".")
io.flush()

-- Change access and modification time
local testdate1 = os.time({ year = 2007, day = 10, month = 2, hour=0})
local testdate2 = os.time({ year = 2007, day = 11, month = 2, hour=0})

assert (lfs.touch (tmpfile, testdate2, testdate1))
local new_att = assert (lfs.attributes (tmpfile))
assert (math.abs(new_att.access - testdate2) <= 1, "could not set access time")
assert (math.abs(new_att.modification - testdate1) <= 1, "could not set modification time")

io.write(".")
io.flush()

-- Checking link (does not work on Windows)
if lfs.link and lfs.link (tmpfile, "_a_link_for_test_", true) then
  assert (lfs.attributes"_a_link_for_test_".mode == "file")
  if lfs.symlinkattributes then
    assert (lfs.symlinkattributes"_a_link_for_test_".mode == "link")
  end
  assert (lfs.link (tmpfile, "_a_hard_link_for_test_"))
  assert (lfs.attributes (tmpfile, "nlink") == 2)
  assert (os.remove"_a_link_for_test_")
  assert (os.remove"_a_hard_link_for_test_")
end

io.write(".")
io.flush()

-- -- Checking text/binary modes (only has an effect in Windows)
-- local f = io.open(tmpfile, "w")
-- local result, mode = lfs.setmode(f, "binary")
-- assert(result) -- on non-Windows platforms, mode is always returned as "binary"
-- result, mode = lfs.setmode(f, "text")
-- assert(result and mode == "binary")
-- f:close()
-- 
-- io.write(".")
-- io.flush()

-- Restore access time to current value
assert (lfs.touch (tmpfile, attrib.access, attrib.modification))
new_att = assert (lfs.attributes (tmpfile))
assert (math.abs(new_att.access - attrib.access) <= 1)
assert (math.abs(new_att.modification - attrib.modification) <= 1)

io.write(".")
io.flush()

-- Remove new file and directory
assert (os.remove (tmpfile), "could not remove new file")
assert (lfs.rmdir (tmpdir), "could not remove new directory")
assert (lfs.mkdir (tmpdir..sep.."lfs_tmp_dir") == nil, "could create a directory inside a non-existent one")

io.write(".")
io.flush()

-- Trying to get attributes of a non-existent file
assert (lfs.attributes ("this couldn't be an actual file") == nil, "could get attributes of a non-existent file")
assert (type(lfs.attributes (upper)) == "table", "couldn't get attributes of upper directory")

io.write(".")
io.flush()

-- Stressing directory iterator (nonexists)
if IS_WINDOWS then
  count = 0
  for i = 1, 4000 do
          for file in lfs.dir (nonexists) do
                  count = count + 1
          end
  end

  io.write(".")
  io.flush()
end

-- Stressing directory iterator (exists)
count = 0
for i = 1, 4000 do
        for file in lfs.dir (current) do
                count = count + 1
        end
end

io.write(".")
io.flush()

-- Stressing directory iterator, explicit version (nonexists)
if IS_WINDOWS then
  count = 0
  for i = 1, 4000 do
    local iter, dir = lfs.dir(nonexists)
    local file = dir:next()
    while file do
      count = count + 1
      file = dir:next()
    end
    assert(not pcall(dir.next, dir))
  end

  io.write(".")
  io.flush()
end

-- Stressing directory iterator, explicit version (exists)
count = 0
for i = 1, 4000 do
  local iter, dir = lfs.dir(current)
  local file = dir:next()
  while file do
    count = count + 1
    file = dir:next()
  end
  assert(not pcall(dir.next, dir))
end

io.write(".")
io.flush()

if IS_WINDOWS then
  -- directory explicit close
  local iter, dir = lfs.dir(nonexists)
  dir:close()
  assert(not pcall(dir.next, dir))

  io.write(".")
  io.flush()
end

-- directory explicit close
local iter, dir = lfs.dir(current)
dir:close()
assert(not pcall(dir.next, dir))
print"Ok!"

end

local pass = true

local function run_test(...)
  local ok, err = pcall(test, ...)
  if not ok then
    print()
    print(err)
  end
  pass = ok and pass
  print("----------------------------------------------------")
end

if IS_WINDOWS then
  if prequire"alien" then 
    local lfs = require"path.win32.fs".load("alien", "A")
    run_test("lfs.alienA", lfs)
  end

  if prequire"ffi" then 
    local lfs = require"path.win32.fs".load("ffi", "A")
    run_test("lfs.ffiA", lfs)
  end
else
  if prequire"path.syscall.fs" then
    local lfs = prequire"path.syscall.fs"
    run_test("lfs.syscall", lfs)
  end
end

if prequire"path.lfs.fs" then
  local lfs = prequire"path.lfs.fs"
  run_test("lfs.lfs", lfs)
end

if not pass then os.exit(-1) end
