local ffi   = require "ffi"
local wcs   = require "path.win32.ffi.wcs"
local types = require "path.win32.ffi.types"

ffi.cdef[[
  void* FindFirstFileA(const CHAR*  pattern, WIN32_FIND_DATAA* fd);
  void* FindFirstFileW(const CHAR*  pattern, WIN32_FIND_DATAW* fd);

  int FindNextFileA(void* ff, WIN32_FIND_DATAA* fd);
  int FindNextFileW(void* ff, WIN32_FIND_DATAW* fd);
  int FindClose(void* ff);     
]]

local WIN32_FIND_DATAA = types.CTYPES.WIN32_FIND_DATAA
local WIN32_FIND_DATAW = types.CTYPES.WIN32_FIND_DATAW
local INVALID_HANDLE   = ffi.cast("void*", -1)
local C = ffi.C

local function FindFirstFile(u, P)
  local ret, fd, err
  if u then
    fd = WIN32_FIND_DATAW()
    ret = C.FindFirstFileW(P .. "\0", fd)
  else
    fd  = WIN32_FIND_DATAA()
    ret = C.FindFirstFileA(P, fd)
  end
  if ret == INVALID_HANDLE then
    local err = C.GetLastError()
    if err == 3 then -- path not found
      return false
    elseif err == 2 then -- file not found
      return false
    else return nil, err end
  end
  ffi.gc(ret, C.FindClose)
  return ret, fd
end

local function FindNextFile(u, h, fd)
  local ret
  if u then ret = C.FindNextFileW(h, fd)
  else ret = C.FindNextFileA(h, fd) end
  return ret
end

local function FindClose(h)
  C.FindClose(ffi.gc(h, nil))
end

local function findfile(u, path, cb)
  local h, fd = u.FindFirstFile(path)
  if not h then return nil, fd end
  repeat
    if cb(u.WIN32_FIND_DATA2TABLE(fd)) then
      u.FindClose(h)
      return true
    end
    ret = u.FindNextFile(h, fd)
  until ret == 0;
  return u.FindClose(h)
end

local _M = {
  A = {
    FindFirstFile   = function(...) return FindFirstFile(false, ...) end;
    FindNextFile    = function(...) return FindNextFile(false, ...)  end;
    FindClose       = FindClose;
    WIN32_FIND_DATA2TABLE = types.CTYPE2LUA.WIN32_FIND_DATAA;
  };
  W = {
    FindFirstFile = function(...) return FindFirstFile(true, ...) end;
    FindNextFile  = function(...) return FindNextFile(true, ...)  end;
    FindClose     = FindClose;
    WIN32_FIND_DATA2TABLE = types.CTYPE2LUA.WIN32_FIND_DATAW;
  };
}

_M.A.findfile = function(...) return findfile(_M.A, ...) end
_M.W.findfile = function(...) return findfile(_M.W, ...) end

return _M

