local TIMER = require "lzmq.timer".monotonic()
local COUNT = 0
local function counter_reset() COUNT = 0 end
local function counter() COUNT = COUNT + 1 end

local function etime(name, fn)
  counter_reset()
  TIMER:reset()
  TIMER:start()
  fn()
  local elapsed = TIMER:stop()
  io.write(name, ' - elapsed: ', elapsed, '(ms) counter: ', COUNT, '\n')
end

local function prequire(name)
  local ok, err = pcall(require, name)
  if ok then return err, name end
  return nil, err
end

local function load_winfs(...)
  local m = prequire"path.win32.fs"
  if not m then return end
  local ok, m = pcall(m.load, ...)
  if ok then return m end
  return nil, err
end

local function run(fs, P)
  etime('generic for', function() for f in fs.each(P,{recurse=true}) do counter() end end)
  etime('   callback', function() fs.each(P,counter,{recurse=true})    end)
  etime('    foreach', function() fs.foreach(P,counter,{recurse=true}) end)
end

if not (arg[1] and arg[2]) then
  print("usage: each_perf <path_to_dir> <mask>")
  return 
end


local DIR_SEP = package.config:sub(1,1)
local base = arg[1]
local mask = arg[2]

if base:sub(-1) ~= DIR_SEP then
  base = base .. DIR_SEP
end

local lfs_each
local lfs  = prequire"lfs"
if lfs then
  function lfs_each(P, cb)
    for name in lfs.dir(P) do if name == '.' or name == '..' then else
      local path = P .. DIR_SEP .. name
      if lfs.attributes(P, "mode") == "directory" then
        lfs_each(path, cb)
      end
      cb(path)
    end end
  end
  -- warmup file system
  lfs_each(base:sub(1,-2),counter)
end

if lfs then
  print("=============================================")
  print("==            lfs.dir                      ==")
  print("without mask:")
  etime("           ", function() lfs_each(base:sub(1,-2), counter) end)
end

local afx = prequire"afx"
if afx then
  print("=============================================")
  print("==          afx.findfile                   ==")
  print("without mask:")
  etime("           ", function()
    afx.findfile{file = base .. "*",skipdirs=false;skipfiles=false;recurse=true;callback=counter}
  end)
  print("---------------------------------------------")
  print("with mask:")
  etime("           ", function()
    afx.findfile{file = base .. mask,skipdirs=false;skipfiles=false;recurse=true;callback=counter}
  end)
end

local fs = prequire "path.lfs.fs"
if fs then
  print("=============================================")
  print("==          path.lfs.fs                    ==")
  print("without mask:")
  run(fs, base)
  print("---------------------------------------------")
  print("with mask:")
  run(fs, base .. mask)
end

local fs = load_winfs("alien", "A")
if fs then
  print("=============================================")
  print("==          path.win32.alien.fs            ==")
  print("without mask:")
  run(fs, base)
  print("with mask:")
  run(fs, base .. mask)
end

local fs = load_winfs("ffi", "A")
if fs then
  print("=============================================")
  print("==          path.win32.ffi.fs              ==")
  print("without mask:")
  run(fs, base)
  print("with mask:")
  run(fs, base .. mask)
end
