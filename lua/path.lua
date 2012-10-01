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

local GetFileAttributes, GetLastError, GetFileAttributesEx, GetFileSize, GetTempPath
if IS_WINDOWS then
  local MAX_PATH  = 260
  local USE_ALIEN = true
  local USE_FFI   = true
  local USE_AFX   = true

  if USE_ALIEN and not GetFileAttributes then -- alien
    local alien = prequire "alien"
    if alien then
      local kernel32 = assert(alien.load("kernel32.dll"))
      GetFileAttributes = assert(kernel32.GetFileAttributesA) -- win2k+
      GetFileAttributes:types{abi="stdcall", ret = "uint", "string"}
      GetLastError = kernel32.GetLastError
      GetLastError:types{ret ='int', abi='stdcall'}

      local GetFileAttributesExA_ = kernel32.GetFileAttributesExA -- winXP+
      if GetFileAttributesExA_ then
        local WIN32_FILE_ATTRIBUTE_DATA = alien.defstruct{
          {"dwFileAttributes",      "uint" };
          {"ftCreationTime_low",    "uint" };
          {"ftCreationTime_high",   "uint" };
          {"ftLastAccessTime_low",  "uint" };
          {"ftLastAccessTime_high", "uint" };
          {"ftLastWriteTime_low",   "uint" };
          {"ftLastWriteTime_high",  "uint" };
          {"nFileSizeHigh",         "uint" };
          {"nFileSizeLow",          "uint" };
        }
        GetFileAttributesExA_:types{abi="stdcall", ret = "int", "string", "int", "pointer"}
        GetFileAttributesEx = function (P)
          local fileInfo = WIN32_FILE_ATTRIBUTE_DATA:new()
          local ret = GetFileAttributesExA_(P, 0, fileInfo())
          if ret == 0 then return nil, GetLastError() end
          return {
            dwFileAttributes = fileInfo.dwFileAttributes;
            ftCreationTime   = {fileInfo.ftCreationTime_low,   fileInfo.ftCreationTime_high};
            ftLastAccessTime = {fileInfo.ftLastAccessTime_low, fileInfo.ftLastAccessTime_high};
            ftLastWriteTime  = {fileInfo.ftLastWriteTime_low,  fileInfo.ftLastWriteTime_high};
            nFileSize        = {fileInfo.nFileSizeLow,         fileInfo.nFileSizeHigh};
          }
        end
      end

      local GetTempPathA_ = kernel32.GetTempPathA -- winXP+
      if GetTempPathA_ then
        GetTempPathA_:types{abi="stdcall", ret = "uint", "uint", "string"}
        GetTempPath = function()
          local buf = alien.buffer(MAX_PATH + 1);
          local ret = GetTempPathA_(buf.size, buf)
          if ret == 0 then return nil, GetLastError() end
          return tostring(buf)
        end
      end
    end
  end

  if USE_FFI   and not GetFileAttributes then -- ffi
    local ffi = prequire "ffi"
    if ffi then
      ffi.cdef [[
          typedef enum _GET_FILEEX_INFO_LEVELS { 
            GetFileExInfoStandard,
            GetFileExMaxInfoLevel 
          } GET_FILEEX_INFO_LEVELS;

          typedef struct _FILETIME {
            uint32_t dwLowDateTime;
            uint32_t dwHighDateTime;
          } FILETIME, *PFILETIME;

          typedef struct _WIN32_FILE_ATTRIBUTE_DATA {
            uint32_t dwFileAttributes;
            FILETIME ftCreationTime;
            FILETIME ftLastAccessTime;
            FILETIME ftLastWriteTime;
            uint32_t nFileSizeHigh;
            uint32_t nFileSizeLow;
          } WIN32_FILE_ATTRIBUTE_DATA, *LPWIN32_FILE_ATTRIBUTE_DATA;

          int GetFileAttributesA(const char *path);
          int GetLastError();
          int GetFileAttributesExA(const char *lpFileName, GET_FILEEX_INFO_LEVELS fInfoLevelId, void* lpFileInformation);
          uint32_t GetTempPathA(uint32_t n, char *buf);
       ]]
      local C = ffi.C
      GetFileAttributes     = ffi.C.GetFileAttributesA
      GetLastError          = ffi.C.GetLastError
      local WIN32_FILE_ATTRIBUTE_DATA = ffi.typeof('WIN32_FILE_ATTRIBUTE_DATA')
      GetFileAttributesEx = function (P)
        local fileInfo = WIN32_FILE_ATTRIBUTE_DATA()
        local ret = C.GetFileAttributesExA_(P, ffi.C.GetFileExInfoStandard, fileInfo)
        if ret == 0 then return nil, C.GetLastError() end
        return {
          dwFileAttributes = fileInfo.dwFileAttributes;
          ftCreationTime   = {fileInfo.ftCreationTime.dwLowDateTime,   fileInfo.ftCreationTime.dwHighDateTime};
          ftLastAccessTime = {fileInfo.ftLastAccessTime.dwLowDateTime, fileInfo.ftLastAccessTime.dwHighDateTime};
          ftLastWriteTime  = {fileInfo.ftLastWriteTime.dwLowDateTime,  fileInfo.ftLastWriteTime.dwHighDateTime};
          nFileSize        = {fileInfo.nFileSizeLow,                   fileInfo.nFileSizeHigh};
        }
      end
      GetTempPath = function()
        local n = MAX_PATH + 1
        local buf = ffi.new("char[?]", n)
        local ret = C.GetTempPathA(n, buf)
        if ret == 0 then return nil, C.GetLastError() end
        if ret > n then 
          n = ret
          buf = ffi.new("char[?]", n+1)
          ret = C.GetTempPathA(n, buf)
          if ret == 0 then return nil, C.GetLastError() end
          if ret > n then ret = n end
        end
        return ffi.string(buf, ret)
      end
    end
  end

  if GetFileAttributesEx then
    GetFileSize = function (P)
      local info, err = GetFileAttributesEx(P)
      if not info then return nil, err end
      return (info.nFileSize[2] * 2^32) + info.nFileSize[1]
    end
  end

  if USE_AFX   and not GetFileAttributes then -- afx
    local afx = prequire "afx"
    if afx then 
      GetFileAttributes = afx.getfileattr
      GetLastError      = afx.lastapierror
      GetFileSize       = afx.filesize
      GetTempPath       = afx.tmpdir
    end
  end

end

--[[ note GetTempPath
GetTempPath() might ignore the environment variables it's supposed to use (TEMP, TMP, ...) if they are more than 130 characters or so.
http://blogs.msdn.com/b/larryosterman/archive/2010/10/19/because-if-you-do_2c00_-stuff-doesn_2700_t-work-the-way-you-intended_2e00_.aspx

---------------
 Limit of Buffer Size for GetTempPath
[Note - this behavior does not occur with the latest versions of the OS as of Vista SP1/Windows Server 2008. If anyone has more information about when this condition occurs, please update this content.]

[Note - this post has been edited based on, and extended by, information in the following post]

Apparently due to the method used by GetTempPathA to translate ANSI strings to UNICODE, this function itself cannot be told that the buffer is greater than 32766 in narrow convention. Attempting to pass a larger value in nBufferLength will result in a failed RtlHeapFree call in ntdll.dll and subsequently cause your application to call DbgBreakPoint in debug compiles and simple close without warning in release compiles.

Example:

// Allocate a 32Ki character buffer, enough to hold even native NT paths.
LPTSTR tempPath = new TCHAR[32767];
::GetTempPath(32767, tempPath);    // Will crash in RtlHeapFree
----------------
--]]


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

function PATH:tmpdir_()
  if PATH.IS_WINDOWS then
    for _, p in ipairs{'TEMP', 'TMP'} do
      dir = os.getenv(p)
      if dir and dir ~= '' then
        break
      end
    end
    return PATH:remove_dir_end(dir)
  end
  return PATH:dirname(os.tmpname())
end
PATH.tmpdir = PATH.tmpdir_
if GetTempPath then
  function PATH:tmpdir()
    local dir = GetTempPath()
    if dir then return PATH:remove_dir_end(dir) end
    return self:tmpdir_()
  end
end

function PATH:tmpname()
  local P = os.tmpname()
  if self:dirname(P) == '' then
    P = self:join(self:tmpdir(), P)
  end
  return P
end

local function file_size(P)
  local f, err = io.open(P, 'rb')
  if not f then return nil, err end
  local size, err = f:seek('end')
  f:close()
  if not size then return nil, err end
  return size
end

if GetFileSize then
  function PATH:size(P)
    local size, err = GetFileSize(P)
    if size then return size end
    return file_size(P)
  end
else 
  function PATH:size(P)
    return file_size(P)
  end
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
      P = self:join(lfs.currentdir(), P)
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

function PATH:ctime(P)
  return self:attrib(P,'change')
end

function PATH:mtime(P)
  return self:attrib(P,'modification')
end

function PATH:atime(P)
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

  PATH.cdate = make_getfiletime_as_date( PATH.ctime );
  PATH.mdate = make_getfiletime_as_date( PATH.mtime );
  PATH.adate = make_getfiletime_as_date( PATH.atime );
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