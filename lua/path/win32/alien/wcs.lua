local alien = require "alien"
local kernel32 = assert(alien.load("kernel32.dll"))
local MultiByteToWideChar_ = assert(kernel32.MultiByteToWideChar)
local WideCharToMultiByte_ = assert(kernel32.WideCharToMultiByte)
local GetLastError         = assert(kernel32.GetLastError)

local DWORD = "uint"
local WCHAR_SIZE = 2

local CP_ACP            = 0           -- default to ANSI code page
local CP_OEM            = 1           -- default to OEM  code page
local CP_MAC            = 2           -- default to MAC  code page
local CP_THREAD_ACP     = 3           -- current thread's ANSI code page
local CP_SYMBOL         = 42          -- SYMBOL translations
local CP_UTF7           = 65000       -- UTF-7 translation
local CP_UTF8           = 65001       -- UTF-8 translation

-- int __stdcall MultiByteToWideChar(UINT cp, DWORD flag, const char* src, int srclen, wchar_t* dst, int dstlen);
MultiByteToWideChar_:types{abi="stdcall", ret = "int",
  "uint",   -- cp
  DWORD,    -- flag
  "string", -- src (const char*)
  "int",    -- srclen
  "string", -- dst (wchar_t*)
  "int"     -- dstlen
}

--int __stdcall WideCharToMultiByte(UINT cp, DWORD flag, const wchar_t* src, int srclen, char* dst, int dstlen, const char* defchar, int* used);
WideCharToMultiByte_:types{abi="stdcall", ret = "int", 
  "int",     -- cp
  DWORD,     -- flag
  "string",  -- src (const wchar_t*)
  "int",     -- srclen
  "string",  -- dst (char*)
  "int",     -- dstlen
  "pointer", -- defchar (char*)
  "pointer"  -- used(int*)
}

GetLastError:types{ret = DWORD, abi='stdcall'}

local function strnlen(data, n)
  if type(data) == 'string' then
    return #data
  end
  n = n or #data
  for i = 1, n do
    if data[i] == 0 then
      return i
    end
  end
  return n
end

local function wcsnlen(data, n)
  if type(data) == 'string' then
    return  math.ceil(#data/2)
  end
  n = n or #data
  for i = 1, (2 * n), 2 do
    if (data[i] == 0) and (data[i+1] == 0) then
      return math.floor( i / 2 )
    end
  end
  return n
end

local function MultiByteToWideChar(src, cp)
  local flag   = true
  local buflen = strnlen(src)
  local dst    = alien.buffer( WCHAR_SIZE * (buflen + 1) ) -- eos
  local ret = MultiByteToWideChar_(cp, 0, src, #src, dst, buflen)
  if ret < 0 then return nil, GetLastError() end
  if ret <= buflen then 
    dst[ret * WCHAR_SIZE    ] = 0
    dst[ret * WCHAR_SIZE + 1] = 0
    return dst, ret
  end
  dst    = alien.buffer(WCHAR_SIZE * 1)
  dst[0] = 0
  dst[1] = 0
  return dst,0
end

local function WideCharToMultiByte(src, cp)
  local srclen = wcsnlen(src)
  local buflen = (srclen + 1)
  while true do
    local dst = alien.buffer(buflen + 1) -- eof
    local ret = WideCharToMultiByte_(cp, 0, src, srclen, dst, buflen, nil, nil)
    if ret <= 0 then 
      local err = GetLastError()
      if err == 122 then -- buffer too small
        buflen = math.ceil(1.5 * buflen)
      else
        return nil, err
      end
    else
      if ret <= buflen then 
        return dst, ret
      end
    end
  end
  dst    = alien.buffer(1)
  dst[0] = 0
  return dst,0
end

local function LUA_M2W(...)
  local dst, dstlen = MultiByteToWideChar(...)
  if not dst then return nil, dstlen end
  return dst:tostring(dstlen * WCHAR_SIZE)
end

local function LUA_W2M(...)
  local dst, dstlen = WideCharToMultiByte(...)
  if not dst then return nil, dstlen end
  return dst:tostring(dstlen)
end

local wcstoutf8 = function (str) return LUA_W2M(str, CP_UTF8) end
local utf8towcs = function (str) return LUA_M2W(str, CP_UTF8) end

local wcstoansi = function (str) return LUA_W2M(str, CP_ACP)  end
local ansitowcs = function (str) return LUA_M2W(str, CP_ACP)  end

local wcstooem  = function (str) return LUA_W2M(str, CP_OEM) end
local oemtowcs  = function (str) return LUA_M2W(str, CP_OEM) end

local _M = {
  MultiByteToWideChar = MultiByteToWideChar;
  WideCharToMultiByte = WideCharToMultiByte;
  mbstowcs            = LUA_M2W;
  wcstombs            = LUA_W2M;
  wcstoutf8           = wcstoutf8;
  utf8towcs           = utf8towcs;
  wcstoansi           = wcstoansi;
  ansitowcs           = ansitowcs;
  wcstooem            = wcstooem;
  oemtowcs            = oemtowcs;
  CP = {
    ACP        = CP_ACP;
    OEM        = CP_OEM;
    MAC        = CP_MAC;
    THREAD_ACP = CP_THREAD_ACP;
    SYMBOL     = CP_SYMBOL;
    UTF7       = CP_UTF7;
    UTF8       = CP_UTF8;
  }
}

return _M