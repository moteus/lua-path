local ffi = require("ffi")
ffi.cdef[[
  int __stdcall MultiByteToWideChar(unsigned int cp, uint32_t flag, const char* src, int srclen, wchar_t* dst, int dstlen);
  int __stdcall WideCharToMultiByte(unsigned int cp, uint32_t flag, const char* src, int srclen, char* dst, int dstlen, const char* defchar, int* used);
  uint32_t __stdcall GetLastError(void);
]]

local C = ffi.C
local achar_t  = ffi.typeof'char[?]'
local awchar_t = ffi.typeof'wchar_t[?]'
local pchar_t  = ffi.typeof'char*'
local pwchar_t = ffi.typeof'wchar_t*'

local function strnlen(data, n)
  if type(data) == 'string' then
    return #data
  end
  if not n then
    if ffi.istype(pchar_t, data) then
      n = math.huge
    else -- assume char[?] / char&[...]
      n = assert(ffi.sizeof(data))
    end
  end
  for i = 0, n-1 do
    if data[i] == 0 then return i end
  end

  return n
end

local function wcsnlen(data, n)
  if type(data) == 'string' then
    return  math.ceil(#data/2)
  end

  if not n then
    if ffi.istype(pchar_t, data) then
      n = math.huge
    else -- assume wchar[?] / wchar&[...]
      n = math.ceil(assert(ffi.sizeof(data))/2)
    end
  end
  for i = 0, n-1 do
    if data[i] == 0 then return i end
  end

  return n
end

local function MultiByteToWideChar(src, cp)
  local flag = true
  local buflen = strnlen(src)
  local dst = ffi.new(awchar_t, buflen + 1) -- eos
  local ret = C.MultiByteToWideChar(cp, 0, src, #src, dst, buflen)
  if ret < 0 then return nil, C.GetLastError() end
  if ret <= buflen then 
    dst[ret] = 0
    return dst, ret
  end
  dst    = ffi.new(awchar_t, 1)
  dst[0] = 0
  return dst,0
end

local function WideCharToMultiByte(src, cp)
  local srclen = wcsnlen(src)
  local buflen = srclen + 1
  if type(src) == 'userdata' then src = ffi.cast('const char*', src) end
  while true do
    local dst = ffi.new("char[?]", buflen + 1) -- eof
    local ret = ffi.C.WideCharToMultiByte(cp, 0, src, srclen, dst, buflen, nil, nil)
    if ret <= 0 then 
      local err = C.GetLastError()
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
  dst    = ffi.new(achar_t, 1)
  dst[0] = 0
  return dst,0
end

local function LUA_W2M(...)
  local dst, dstlen = WideCharToMultiByte(...)
  if not dst then return nil, dstlen end
  return ffi.string(dst, dstlen)
end

local const_pchar_t = ffi.typeof'char*'
local function LUA_M2W(...)
  local dst, dstlen = MultiByteToWideChar(...)
  if not dst then return nil, dstlen end
  return ffi.string(ffi.cast(const_pchar_t, dst), dstlen*2)
end

local _M = {
  MultiByteToWideChar = MultiByteToWideChar;
  WideCharToMultiByte = WideCharToMultiByte;
  mbstowcs            = LUA_M2W;
  wcstombs            = LUA_W2M;
}

return _M
