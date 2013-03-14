local pacakge = require "package"
local string  = require "string"
local table   = require "table"
local os      = require "os"
local io      = require "io"

local USE_ALIEN = true
local USE_FFI   = true
local USE_AFX   = true

local DIR_SEP = package.config:sub(1,1)
local IS_WINDOWS = DIR_SEP == '\\'

local PATH = {}

PATH.DIR_SEP    = DIR_SEP
PATH.IS_WINDOWS = IS_WINDOWS

--
-- PATH manipulation 

function PATH:unquote(P)
  P = trim(P)
  if P:sub(1,1) == '"' and P:sub(-1,-1) == '"' then
    return (P:sub(2,-2))
  end
  return P
end

function PATH:quote(P)
  if P:find("%s") then
    return '"' .. P .. '"'
  end
  return P
end

function PATH:has_dir_end(P)
  return (string.find(P, '[\\/]$')) and true
end

function PATH:remove_dir_end(P)
  return (string.gsub(P, '[\\/]+$', ''))
end

function PATH:ensure_dir_end(P)
  return self:remove_dir_end(P) .. self.DIR_SEP 
end

function PATH:isunc(P)
  return (string.sub(P, 1, 2) == (self.DIR_SEP .. self.DIR_SEP)) and P
end

function PATH:normolize_sep(P)
  return (string.gsub(P, '\\', self.DIR_SEP):gsub('/', self.DIR_SEP))
end

function PATH:normolize(P)
  P = self:normolize_sep(P)
  local DIR_SEP = self.DIR_SEP

  local is_unc = self:isunc(P)
  P = string.gsub(P, DIR_SEP .. '%.' .. DIR_SEP, DIR_SEP):gsub(DIR_SEP .. DIR_SEP, DIR_SEP)
  if is_unc then P = DIR_SEP .. P end

  local root, path = nil, P
  if is_unc then
    root, path = self:splitroot(P)
  end

  path = self:ensure_dir_end(path)
  while true do
    local first, last = string.find(path, DIR_SEP .. "[^".. DIR_SEP .. "]+" .. DIR_SEP .. '%.%.' .. DIR_SEP)
    if not first then break end
    path = string.sub(path, 1, first) .. string.sub(path, last+1)
  end
  P = path

  if root then -- unc
    assert(is_unc)
    P = P:gsub( '%.%.?' .. DIR_SEP , '')
    P = DIR_SEP .. DIR_SEP .. self:join(root, P)
  elseif self.IS_WINDOWS then 
    -- c:\..\foo => c:\foo
    -- \..\foo => \foo
    local root, path = self:splitroot(P)
    if root ~= '' or P:sub(1,1) == DIR_SEP then
      path = path:gsub( '%.%.?' .. DIR_SEP , '')
      P = self:join(root, path)
    end
  end

  if self.IS_WINDOWS and #P <= 3 and P:sub(2,2) == ':' then -- c: => c:\ or c:\ => c:\
    if #P == 2 then return P .. self.DIR_SEP end
    return P
  end
 
  return self:remove_dir_end(P)
end

function PATH:join_(P1, P2)
  local ch = P2:sub(1,1)
  if (ch == '\\') or (ch == '/') then
    return self:remove_dir_end(P1) .. P2
  end
  return self:ensure_dir_end(P1) .. P2
end

function PATH:join(...)
  local t,n = {...}, select('#', ...)
  local r = t[1]
  for i = 2, #t do r = self:join_(r,t[i]) end
  return r
end

function PATH:splitext(P)
  local s1,s2 = string.match(P,"(.-)([.][^\\/.]*)$")
  if s1 then return s1,s2 end
  return P, ''
end

function PATH:splitpath(P)
  return string.match(P,"^(.-)[\\/]?([^\\/]*)$")
end

function PATH:splitroot(P)
  if self.IS_WINDOWS then
    if self:isunc(P) then
      return string.match(P, [[^\\([^\/]+)[\]?(.*)$]])
    end
    if string.sub(P,2,2) == ':' then
      return string.sub(P,1,2), string.sub(P,4)
    end
    return '', P
  else
    if string.sub(P,1,1) == '/' then 
      return string.match(P,[[^/([^\/]+)[/]?(.*)$]])
    end
    return '', P
  end
end

function PATH:basename(P)
  local s1,s2 = self:splitpath(P)
  return s2
end

function PATH:dirname(P)
  return (self:splitpath(P))
end

function PATH:extension(P)
  local s1,s2 = self:splitext(P)
  return s2
end

function PATH:root(P)
  return (self:splitroot(P))
end

function PATH:isfullpath(P)
  return (self:root(P) ~= '') and P
end

function PATH:user_home()
  if IS_WINDOWS then
    return os.getenv('USERPROFILE') or PATH:join(os.getenv('HOMEDRIVE'), os.getenv('HOMEPATH'))
  end
  return os.getenv('HOME')
end

local function prequire(m) 
  local ok, err = pcall(require, m) 
  if not ok then return nil, err end
  return err
end

local fs 

if not fs and IS_WINDOWS then
  local fsload = require"path.win32.fs".load
  local ok, mod = pcall(fsload, "ffi", "A") or pcall(fsload, "alien", "A")
  fs = ok and mod
end

if not fs then
  fs = prequire"path.lfs.fs"
end

if fs then

--
-- PATH based on system 

local function assert_system(self)
  if PATH.IS_WINDOWS then assert(self.IS_WINDOWS) return end
  assert(not self.IS_WINDOWS)
end

if fs.flags then
  function PATH:flags(P, ...)
    assert_system(self)
    P = self:fullpath(P)
    return fs.flags(P, ...)
  end
end

function PATH:tmpdir()
  assert_system(self)
  return self:remove_dir_end(fs.tmpdir())
end

function PATH:tmpname()
  local P = os.tmpname()
  if self:dirname(P) == '' then
    P = self:join(self:tmpdir(), P)
  end
  return P
end

function PATH:size(P)
  assert_system(self)
  return fs.size(P)
end

function PATH:fullpath(P)
  if not self:isfullpath(P) then 
    P = self:normolize_sep(P)
    local ch1, ch2 = P:sub(1,1), P:sub(2,2)
    if ch1 == '~' then --  ~\temp
      P = self:join(self:user_home(), P:sub(2))
    elseif self.IS_WINDOWS and (ch1 == self.DIR_SEP) then -- \temp => c:\temp
      local root = self:root(self:currentdir())
      P = self:join(root, P)
    else
      P = self:join(self:currentdir(), P)
    end
  end

  return self:normolize(P)
end

function PATH:attrib(P, ...)
  assert_system(self)
  return fs.attributes(P, ...)
end

function PATH:exists(P)
  assert_system(self)
  return fs.exists(self:fullpath(P))
end

function PATH:isdir(P)
  assert_system(self)
  return fs.isdir(self:fullpath(P))
end

function PATH:isfile(P)
  assert_system(self)
  return fs.isfile(self:fullpath(P))
end

function PATH:islink(P)
  assert_system(self)
  return fs.islink(self:fullpath(P))
end

function PATH:ctime(P)
  assert_system(self)
  return fs.ctime(self:fullpath(P))
end

function PATH:mtime(P)
  assert_system(self)
  return fs.mtime(self:fullpath(P))
end

function PATH:atime(P)
  assert_system(self)
  return fs.atime(self:fullpath(P))
end

function PATH:touch(P, ...)
  assert_system(self)
  return fs.touch(self:fullpath(P), ...)
end

function PATH:currentdir()
  assert_system(self)
  return self:normolize(fs.currentdir())
end

function PATH:chdir(P)
  assert_system(self)
  return fs.chdir(self:fullpath(P))
end

local date = prequire "date"
if date then
  local function make_getfiletime_as_date(fn)
    if date then
      return function(...)
        local t,e = fn(...)
        if not t then return nil, e end
        return date(t)
      end
    end
  end

  PATH.cdate = make_getfiletime_as_date( PATH.ctime );
  PATH.mdate = make_getfiletime_as_date( PATH.mtime );
  PATH.adate = make_getfiletime_as_date( PATH.atime );
end

function PATH:mkdir(P)
  assert_system(self)
  local P = self:fullpath(P)
  if self:exists(P) then return self:isdir(P) end
  local p = ''
  P = self:ensure_dir_end(P)
  for str in string.gmatch(P, '.-' .. self.DIR_SEP) do
    p = p .. str
    if self:exists(p) then
      if not self:isdir(p) then
        return nil, 'can not create ' .. p
      end
    else
      local ok, err = fs.mkdir(self:remove_dir_end(p))
      if not ok then return nil, err .. ' ' .. p end
    end
  end

  return P
end

function PATH:rmdir(P)
  assert_system(self)
  return fs.rmdir(self:fullpath(P))
end

function PATH:rename(from,to,force)
  if not self:isfile(from) then return nil, "file not found" end
  if self:exists(to) and force then
    local ok, err = self:remove(to)
    if not ok then return nil, err end
  end
  return os.rename(from, to)
end

function each_impl(opt)
  opt.file = PATH:fullpath(opt.file)
  return fs.each_impl(opt)
end

local each = require "path.findfile".load(function(opt)
  opt.file = PATH:fullpath(opt.file)
  return fs.each_impl(opt)
end)

function PATH:each(...)
  assert_system(self)
  return each(...)
end

local function copy_impl_batch(fs, src_dir, mask, dst_dir, opt)
  if not opt then opt = {} end

  local overwrite = opt.overwrite
  local accept    = opt.accept
  local onerror   = opt.error
  local chlen     = #fs.DIR_SEP
  local count     = 0

  local ok, err = fs.each_impl{file = src_dir .. fs.DIR_SEP .. mask,
    delay = opt.delay; recurse = opt.recurse; param = "pnm";
    skipdirs = opt.skipdirs; skipfiles = opt.skipfiles;
    callback = function(path, name, mode)
      local rel = string.sub(path, #src_dir + chlen + 1)
      if #rel > 0 then rel = rel .. fs.DIR_SEP .. name else rel = name end
      local dst = dst_dir .. fs.DIR_SEP .. rel
      local src = path .. fs.DIR_SEP .. name

      if accept then
        local ok = accept(src, dst, opt)
        if not ok then return end
      end

      local ok, err
      if mode == "directory" then ok, err = fs.mkdir(dst)
      else ok, err = fs.copy(src, dst, not overwrite) end

      if not ok and onerror then
        if not onerror(err, src, dst, opt) then -- break
          return true
        end
      else
        count = count + 1
      end
    end;
  }
  if ok or err then return ok, err end
  return count
end

local function remove_impl_batch(fs, src_dir, mask, opt)
  if not opt then opt = {} end

  local overwrite = opt.overwrite
  local accept    = opt.accept
  local onerror   = opt.error
  local chlen     = #fs.DIR_SEP
  local count     = 0
  local delay     = (opt.delay == nil) and true or opt.delay

  local ok, err = fs.each_impl{file = src_dir .. fs.DIR_SEP .. mask,
    delay = delay; recurse = opt.recurse; reverse = true; param = "fm";
    skipdirs = opt.skipdirs; skipfiles = opt.skipfiles;
    callback = function(src, mode)
      if accept then
        local ok = accept(src, opt)
        if not ok then return end
      end

      local ok, err
      if mode == "directory" then ok, err = fs.rmdir(src)
      else ok, err = fs.remove(src) end

      if not ok and onerror then
        if not onerror(err, src, opt) then -- break
          return true
        end
      else
        count = count + 1
      end
    end;
  }
  if ok or err then return ok, err end
  return count
end

function PATH:remove_impl(P)
  if self:isdir(P) then return fs.rmdir(P) end
  return fs.remove(P)
end

function PATH:copy(from, to, opt)
  from = self:fullpath(from)
  to   = self:fullpath(to)

  local overwrite = opt and opt.overwrite
  local recurse   = opt and opt.recurse

  local src_dir, src_name = self:splitpath(from)
  if recurse or src_name:find("[*?]") then -- batch mode
    self:mkdir(to)
    return copy_impl_batch(fs, src_dir, src_name, to, opt)
  end
  if self.mkdir then self:mkdir(self:dirname(to)) end
  return fs.copy(from, to, not not overwrite)
end

function PATH:remove(P, opt)
  assert_system(self)
  local P = self:fullpath(P)
  local dir, name = self:splitpath(P)
  if (opt and opt.recurse) or name:find("[*?]") then -- batch mode
    return remove_impl_batch(fs, dir, name, opt)
  end
  return self:remove_impl(P)
end

end -- fs 

local function make_module()
  local M = require "path.module"
  for k, f in pairs(PATH) do
    if type(f) == 'function' then
      M[k] = function(...) return f(PATH, ...) end
    else 
      M[k] = f
    end
  end
  return M
end

local M = make_module()

function M.new(DIR_SEP)
  local o = setmetatable({}, {__index = PATH})
  if type(DIR_SEP) == 'string' then
    o.DIR_SEP = DIR_SEP
    o.IS_WINDOWS = (DIR_SEP == '\\')
  else
    assert(type(DIR_SEP) == 'boolean')
    o.IS_WINDOWS = DIR_SEP
    o.DIR_SEP = o.IS_WINDOWS and '\\' or '/'
  end

  return o
end

return M
