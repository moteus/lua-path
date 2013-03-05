local LOADED = {}

local function load(type)
  if LOADED[type] then return LOADED[type] end
  local _M  = require("path.win32." .. type ..".find")

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

  _M.A.findfile = function(...) return findfile(_M.A, ...) end
  _M.W.findfile = function(...) return findfile(_M.W, ...) end

  LOADED[type] = _M

  return _M
end

return {
  load = load
}