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
  local s1,s2 = string.match(P,"(.-)([.][^\\/]*)$")
  if s1 then return s1,s2 end
  return P, ''
end

function PATH:splitpath(P)
  return string.match(P,"^(.-)([^\\/]*)$")
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
  local s1,s2 = self:splitroot(P)
  return s2
end

function PATH:isfullpath(P)
  return (self:root(P) ~= '') and P
end

--
-- PATH based on system 

local function prequire(m) 
  local ok, err = pcall(require, m) 
  if not ok then return nil, err end
  return err
end

local function assert_system(self)
  if PATH.IS_WINDOWS then assert(self.IS_WINDOWS) return end
  assert(not self.IS_WINDOWS)
end

local GetFileAttributes, GetLastError
if IS_WINDOWS then

  if not GetFileAttributes then -- alien
    local alien = prequire "alien"
    if alien then
      local kernel32 = assert(alien.load("kernel32.dll"))
      GetFileAttributes = assert(kernel32.GetFileAttributesA) -- win2k+
      GetFileAttributes:types{abi="stdcall", ret = "int", "string"}
      GetLastError = kernel32.GetLastError
      GetLastError:types{ret ='int', abi='stdcall'}
    end
  end

  if not GetFileAttributes then -- ffi
    local ffi = prequire "ffi"
    if ffi then
      ffi.cdef [[
          int GetFileAttributesA(const char *path);
          int GetLastError();
       ]]
      GetFileAttributes = ffi.C.GetFileAttributesA
      GetLastError      = ffi.C.GetLastError
    end
  end

  if not GetFileAttributes then -- afx
    local afx = prequire "afx"
    if afx then 
      GetFileAttributes = afx.getfileattr
      GetLastError      = afx.lastapierror
    end
  end

end

if GetFileAttributes then
  function PATH:fileattrib(P, ...)
    assert_system(self)

    P = self:fullpath(P)
    if self.IS_WINDOWS then
      if #P <= 3 and P:sub(2,2) == ':' then -- c: => c:\ or c:\ => c:\
        P = self:ensure_dir_end(P) 
      else -- c:\temp\ => c:\temp
        P = self:remove_dir_end(P) 
      end
    end

    return GetFileAttributes(P, ...)
  end
end

function PATH:user_home()
  if IS_WINDOWS then -- system
    return os.getenv('USERPROFILE') or PATH:join(os.getenv('HOMEDRIVE'), os.getenv('HOMEPATH'))
  end
  return os.getenv('HOME')
end

local lfs  = prequire "lfs"
if lfs then

function PATH:fullpath(P)
  assert_system(self)

  if not self:isfullpath(P) then 
    P = self:normolize_sep(P)
    local ch1, ch2 = P:sub(1,1), P:sub(2,2)
    if ch1 == '~' then --  ~\temp
      P = self:join(self:user_home(), P:sub(2))
    elseif self.IS_WINDOWS and (ch1 == self.DIR_SEP) then -- \temp => c:\temp
      local root = self:root(lfs.currentdir())
      P = self:join(root, P)
    else
      P = self:join(lfs.currentdir())
    end
  end

  return self:normolize(P)
end

function PATH:attrib(P, ...)
  assert_system(self)

  P = self:fullpath(P)
  if self.IS_WINDOWS then
    if #P <= 3 and P:sub(2,2) == ':' then -- c: => c:\ or c:\ => c:\
      P = self:ensure_dir_end(P) 
    else -- c:\temp\ => c:\temp
      P = self:remove_dir_end(P) 
    end
  end

  return lfs.attributes(P, ...)
end

function PATH:exists(P)
  return self:attrib(P,'mode') ~= nil and P
end

function PATH:isdir(P)
  return self:attrib(P,'mode') == 'directory' and P
end

function PATH:isfile(P)
  return self:attrib(P,'mode') == 'file' and P
end

function PATH:islink(P)
  return self:attrib(P,'mode') == 'link' and P
end

function PATH:getctime(P)
  return self:attrib(P,'change')
end

function PATH:getmtime(P)
  return self:attrib(P,'modification')
end

function PATH:getatime(P)
  return self:attrib(P,'access')
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

  PATH.getcdate = make_getfiletime_as_date( PATH.getctime );
  PATH.getmdate = make_getfiletime_as_date( PATH.getmtime );
  PATH.getadate = make_getfiletime_as_date( PATH.getatime );
end

function PATH:mkdir(P)
  local P = self:fullpath(P)
  if self:exists(P) then return self:isdir(P) and P end
  local p = ''
  P = self:ensure_dir_end(P)
  for str in string.gmatch(P, '.-' .. self.DIR_SEP) do
    p = p .. str
    if self:exists(p) then
      if not self:isdir(p) then
        return nil, 'can not create ' .. p
      end
    else
      local ok, err = lfs.mkdir(self:remove_dir_end(p))
      if not ok then return nil, err .. ' ' .. p end
    end
  end

  return P
end

function PATH:matchfiles(mask, recursive, cb)
  assert_system(self)
  local self_ = self
  
  local function filePat2rexPat(pat)
    local pat = pat:gsub("%.","%%%."):gsub("%*",".*"):gsub("%?", ".")
    if IS_WINDOWS then pat = pat:upper() end
    return pat
  end

  local basepath,mask = self:splitpath(mask)
  mask = filePat2rexPat(mask)

  local function match(s, pat)
    if IS_WINDOWS then s = string.upper(s) end
    return nil ~= string.find(s, pat)
  end

  local function filelist (path, pat, cb)
    for file in lfs.dir(path) do if file ~= "." and file ~= ".." then
      local cur_file = self_:join(path, file)
      if self_:isfile(cur_file) then
        if match(file, pat) then 
          cb(path, file)
        end
      end
    end end
    return true
  end

  local function filelist_recurcive (path, pat, cb)
    filelist(path, pat, cb)
    for file in lfs.dir(path) do if file ~= "." and file ~= ".." then
      local cur_dir = self_:join(path, file)
      if self_:isdir(cur_dir) then
        files = filelist_recurcive(cur_dir, pat, cb)
      end
    end end
    return true
  end

  if recursive then
    return filelist_recurcive(basepath, mask, cb)
  end
  return filelist(basepath, mask, cb)
end

end

local function make_module()
  local M = {}
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