local alien = require "alien"
local autil = require "path.win32.alien.utils"


local kernel32        = assert(alien.load("kernel32.dll"))
local FindFirstFileA_ = assert(kernel32.FindFirstFileA)
local FindFirstFileW_ = assert(kernel32.FindFirstFileW)
local FindNextFileA_  = assert(kernel32.FindNextFileA)
local FindNextFileW_  = assert(kernel32.FindNextFileW)
local FindClose_      = assert(kernel32.FindClose)
local GetLastError    = assert(kernel32.GetLastError)

assert( alien.sizeof("pointer") == alien.sizeof("size_t") )
FindFirstFileA_:types{abi="stdcall", ret = "size_t", "string","pointer"}
FindFirstFileW_:types{abi="stdcall", ret = "size_t", "string","pointer"}
FindNextFileA_:types {abi="stdcall", ret = "int", "size_t", "pointer" }
FindNextFileW_:types {abi="stdcall", ret = "int", "size_t", "pointer" }
FindClose_:types{abi="stdcall", ret = "int", "size_t" }
GetLastError:types{ret = DWORD, abi='stdcall'}

local INVALID_HANDLE = autil.cast(-1, "size_t")

local MAX_PATH = 260
local CHAR     = function(N)  return "c" .. N end
local DWORD    = "I4"

local function pad(str, n, ch)
  if #str <= n then
    return str .. (ch or '\0'):rep(n - #str)
  end
  return str
end

local FILETIME = autil.define_struct{
  {DWORD, "dwLowDateTime"  };
  {DWORD, "dwHighDateTime" };
}

local WIN32_FIND_DATAA = autil.define_struct{
  { DWORD           ,"dwFileAttributes"   };
  { FILETIME        ,"ftCreationTime"     };
  { FILETIME        ,"ftLastAccessTime"   };
  { FILETIME        ,"ftLastWriteTime"    };
  { DWORD           ,"nFileSizeHigh"      };
  { DWORD           ,"nFileSizeLow"       };
  { DWORD           ,"dwReserved0"        };
  { DWORD           ,"dwReserved1"        };
  { CHAR(MAX_PATH)  ,"cFileName"          };
  { CHAR(14)        ,"cAlternateFileName" };
}

local WIN32_FIND_DATAW = autil.define_struct{
  { DWORD           ,"dwFileAttributes"   };
  { FILETIME        ,"ftCreationTime"     };
  { FILETIME        ,"ftLastAccessTime"   };
  { FILETIME        ,"ftLastWriteTime"    };
  { DWORD           ,"nFileSizeHigh"      };
  { DWORD           ,"nFileSizeLow"       };
  { DWORD           ,"dwReserved0"        };
  { DWORD           ,"dwReserved1"        };
  { CHAR(2*MAX_PATH),"cFileName"          };
  { CHAR(2*14)      ,"cAlternateFileName" };
}

local WIN32_FILE_ATTRIBUTE_DATA = function(s) return {
  dwFileAttributes = s.dwFileAttributes;
  ftCreationTime   = {s.ftCreationTime.dwLowDateTime,   s.ftCreationTime.dwHighDateTime};
  ftLastAccessTime = {s.ftLastAccessTime.dwLowDateTime, s.ftLastAccessTime.dwHighDateTime};
  ftLastWriteTime  = {s.ftLastWriteTime.dwLowDateTime,  s.ftLastWriteTime.dwHighDateTime};
  nFileSize        = {s.nFileSizeLow,                   s.nFileSizeHigh};
}end;

local WIN32_FIND_DATAA2LUA = function(s) 
  local res = WIN32_FILE_ATTRIBUTE_DATA(s)
  res.cFileName = s.cFileName:gsub("%z.*$", "")
  return res
end;

local WIN32_FIND_DATAW2LUA = function(s)
  local res = WIN32_FILE_ATTRIBUTE_DATA(s)
  res.cFileName = s.cFileName:gsub("%z%z.*$", "")
  return res
end;

local function FindClose(h)
  FindClose_(autil.gc_null(h))
end

local function FindFirstFile(u, P)
  local ret, fd, err
  if u then
    fd  = WIN32_FIND_DATAW:new()
    ret = FindFirstFileW_(P .. "\0", fd())
  else
    fd  = WIN32_FIND_DATAA:new()
    ret = FindFirstFileA_(P, fd())
  end

  if ret == INVALID_HANDLE then
    local err = GetLastError()
    if err == 3 then -- path not found
      return false
    elseif err == 2 then -- file not found
      return false
    else return nil, err end
  end

  ret = autil.gc_wrap(ret, FindClose_)
  return ret, fd
end

local function FindNextFile(u, h, fd)
  local ret
  if u then ret = FindNextFileW_(h.value, fd())
  else ret = FindNextFileA_(h.value, fd()) end
  return ret
end

local _M = {
  A = {
    FindFirstFile   = function(...) return FindFirstFile(false, ...) end;
    FindNextFile    = function(...) return FindNextFile(false, ...)  end;
    FindClose       = FindClose;
    WIN32_FIND_DATA2TABLE = WIN32_FIND_DATAA2LUA;
  };
  W = {
    FindFirstFile = function(...) return FindFirstFile(true, ...) end;
    FindNextFile  = function(...) return FindNextFile(true, ...)  end;
    FindClose     = FindClose;
    WIN32_FIND_DATA2TABLE = WIN32_FIND_DATAW2LUA;
  };
}

return _M