local PATH = require "path.module"
local LOADED = {}

local FILE_ATTRIBUTE_ARCHIVE             = 0x20;    -- A file or directory that is an archive file or directory. Applications typically use this attribute to mark files for backup or removal . 
local FILE_ATTRIBUTE_COMPRESSED          = 0x800;   -- A file or directory that is compressed. For a file, all of the data in the file is compressed. For a directory, compression is the default for newly created files and subdirectories.
local FILE_ATTRIBUTE_DEVICE              = 0x40;    -- This value is reserved for system use.
local FILE_ATTRIBUTE_DIRECTORY           = 0x10;    -- The handle that identifies a directory.
local FILE_ATTRIBUTE_ENCRYPTED           = 0x4000;  -- A file or directory that is encrypted. For a file, all data streams in the file are encrypted. For a directory, encryption is the default for newly created files and subdirectories.
local FILE_ATTRIBUTE_HIDDEN              = 0x02;    -- The file or directory is hidden. It is not included in an ordinary directory listing.
local FILE_ATTRIBUTE_INTEGRITY_STREAM    = 0x8000;  -- The directory or user data stream is configured with integrity (only supported on ReFS volumes). It is not included in an ordinary directory listing. The integrity setting persists with the file if it's renamed. If a file is copied the destination file will have integrity set if either the source file or destination directory have integrity set. (This flag is not supported until Windows Server 2012.)
local FILE_ATTRIBUTE_NORMAL              = 0x80;    -- A file that does not have other attributes set. This attribute is valid only when used alone.
local FILE_ATTRIBUTE_NOT_CONTENT_INDEXED = 0x2000;  -- The file or directory is not to be indexed by the content indexing service.
local FILE_ATTRIBUTE_NO_SCRUB_DATA       = 0x20000; -- The user data stream not to be read by the background data integrity scanner (AKA scrubber). When set on a directory it only provides inheritance. This flag is only supported on Storage Spaces and ReFS volumes. It is not included in an ordinary directory listing. This flag is not supported until Windows 8 and Windows Server 2012.
local FILE_ATTRIBUTE_OFFLINE             = 0x1000;  -- The data of a file is not available immediately. This attribute indicates that the file data is physically moved to offline storage. This attribute is used by Remote Storage, which is the hierarchical storage management software. Applications should not arbitrarily change this attribute.
local FILE_ATTRIBUTE_READONLY            = 0x01;    -- A file that is read-only. Applications can read the file, but cannot write to it or delete it. This attribute is not honored on directories. For more information, see You cannot view or change the Read-only or the System attributes of folders in Windows Server 2003, in Windows XP, in Windows Vista or in Windows 7.
local FILE_ATTRIBUTE_REPARSE_POINT       = 0x400;   -- A file or directory that has an associated reparse point, or a file that is a symbolic link.
local FILE_ATTRIBUTE_SPARSE_FILE         = 0x200;   -- A file that is a sparse file.
local FILE_ATTRIBUTE_SYSTEM              = 0x04;    -- A file or directory that the operating system uses a part of, or uses exclusively.
local FILE_ATTRIBUTE_TEMPORARY           = 0x100;   -- A file that is being used for temporary storage. File systems avoid writing data back to mass storage if sufficient cache memory is available, because typically, an application deletes a temporary file after the handle is closed. In that scenario, the system can entirely avoid writing the data. Otherwise, the data is written after the handle is closed.
local FILE_ATTRIBUTE_VIRTUAL             = 0x10000; --


local function ton(t) return t[1] + t[2] * 2^32 end

local attribs = {
  f = function(path, fd) return path                    end;
  n = function(path, fd) return PATH.basename(path)     end;
  a = function(path, fd) return fd.dwFileAttributes     end;
  z = function(path, fd) return ton(fd.nFileSize)       end;
  t = function(path, fd) return PATH.mtime(path)        end;
  c = function(path, fd) return PATH.ctime(path)        end;
  l = function(path, fd) return PATH.atime(path)        end;

  --- @todo use fd to return times
  -- t = function(path, fd) return FileTimeTo???( ton(fd.ftLastWriteTime)  ) end;
  -- c = function(path, fd) return FileTimeTo???( ton(fd.ftCreationTime)   ) end;
  -- l = function(path, fd) return FileTimeTo???( ton(fd.ftLastAccessTime) ) end;
}

local function make_attrib(str)
  local t = {}
  for i = 1, #str do 
    local ch = str:sub(i,i)
    local fn = attribs[ ch ]
    if not fn then return nil, 'unknown file attribute: ' .. ch end
    table.insert(t, fn)
  end

  return function(...)
    local res = {}
    for i, f in ipairs(t) do
      local ok, err = f(...)
      if ok == nil then return nil, err end
      table.insert(res, ok)
    end
    return res
  end
end

local function prequire (...)
  local ok, mod = pcall(require, ...)
  if not ok then return nil, mod end
  return mod
end

local function isdir(P, fd)
  return PATH.isdir(P)
end

local function fs_foreach(findfile, base, mask, callback, option)
  if option.recurse then
    if fs_foreach(findfile, base, "*", 
      function(path, fd)
        return fs_foreach(findfile, path, mask, callback, option)
      end,{skipfiles = true, recurse = false}
    )then
      return true
    end
  end

  return findfile(PATH.join(base, mask), function(fd)
    if fd.cFileName == '.' or fd.cFileName == '..' then return end
    local fullpath = PATH.join(base, fd.cFileName)
    if isdir(fullpath, fd) then if option.skipdirs then return end
    else if option.skipfiles then return end end
    return callback(fullpath, fd)
  end)
end

local function findfile_t_impl(findfile, option)
  if not option.file then return nil, 'no file mask present' end

  local path, mask = PATH.splitpath( option.file )
  if not PATH.isdir(path) then return end
  path = PATH.fullpath(path)

  local get_params, err = make_attrib(option.param or 'f')
  if not get_params then return nil, err end
  local unpack = unpack or table.unpack

  local filter = option.filter

  if option.callback then
    local callback = option.callback 

    local function cb(path, fd)
      local params = assert(get_params(path, fd))
      if filter and (not filter(unpack(params))) then return end
      return callback(unpack(params))
    end
    return fs_foreach(findfile, path, mask, cb, option)
  else
    local function cb(path, fd)
      local params = assert(get_params(path, fd))
      if filter and (not filter(unpack(params))) then return end
      coroutine.yield(params)
    end
    local co = coroutine.create(function()
      fs_foreach(findfile, path, mask, cb, option)
    end)
    return function()
      local status, params = coroutine.resume(co)
      if status and params then return unpack(params) end
    end
  end
end

local function findfile(u, path, cb)
  local h, fd = u.FindFirstFile(path)
  if not h then return nil, fd end
  repeat
    local ret = cb(u.WIN32_FIND_DATA2TABLE(fd))
    if ret then
      u.FindClose(h)
      return ret
    end
    ret = u.FindNextFile(h, fd)
  until ret == 0;
  return u.FindClose(h)
end

local bit = prequire("bit") or prequire("bit32")
if bit then
  isdir = function(P, fd)
    return (0 ~= bit.band(fd.dwFileAttributes, FILE_ATTRIBUTE_DIRECTORY) and P or false)
  end
end

local function load(type)
  if LOADED[type] then return LOADED[type] end
  local _M  = require("path.win32." .. type ..".find")

  _M.A.findfile = function(...) return findfile(_M.A, ...) end
  _M.W.findfile = function(...) return findfile(_M.W, ...) end

  _M.A.findfile_t = function(...) return findfile_t_impl(_M.A.findfile, ...) end
  _M.W.findfile_t = function(...) return findfile_t_impl(_M.W.findfile, ...) end

  local attribs = {
    f = function(path, name, fd) return PATH.join(path, name) end;
    n = function(path, name, fd) return PATH.basename(path) end;
    a = function(path, name, fd) return PATH.fileattrib and PATH.fileattrib(path) or 0 end;
    z = function(path, name, fd) return PATH.isdir(path) and 0 or PATH.size(path) end;
    t = function(path, name, fd) return PATH.mtime(path) end;
    c = function(path, name, fd) return PATH.ctime(path) end;
    l = function(path, name, fd) return PATH.atime(path) end;
  }

  local function make_attrib(str)
    local t = {}
    for i = 1, #str do 
      local ch = str:sub(i,i)
      local fn = attribs[ ch ]
      if not fn then return nil, 'unknown file attribute: ' .. ch end
      table.insert(t, fn)
    end

    return function(path)
      local res = {}
      for i, f in ipairs(t) do
        local ok, err = f(path)
        if ok == nil then return nil, err end
        table.insert(res, ok)
      end
      return res
    end
  end

  local function findfile_t(option)
    if not option.file then return nil, 'no file mask present' end

    local path, mask = PATH.splitpath( option.file )
    if not PATH.isdir(path) then return end
    path = PATH.fullpath(path)

    local get_params, err = make_attrib(option.param or 'f')
    if not get_params then return nil, err end
    local unpack = unpack or table.unpack

    local filter = option.filter

    local match = function(path)
      return 
        mask_match(PATH.basename(path)) and
        not (option.skipdirs and PATH.isdir(path)) and
        not (option.skipfiles and PATH.isfile(path))
    end

    if option.callback then
      local callback = option.callback 

      local function cb(path)
        local params = assert(get_params(path))
        if filter and (not filter(unpack(params))) then return end
        return callback(unpack(params))
      end

      return fs_foreach(path, match, cb, option.recurse)
    else
      local function cb(path)
        local params = assert(get_params(path))
        if filter and (not filter(unpack(params))) then return end
        coroutine.yield(params)
      end
      local co = coroutine.create(function()
        fs_foreach(path, match, cb, option.recurse)
      end)
      return function()
        local status, params = coroutine.resume(co)
        if status and params then return unpack(params) end
      end
    end
  end

  LOADED[type] = _M

  return _M
end

if false then

require"path"
local m = load("alien")

m.A.findfile_t{
  file = "./*.*";
  param = "ftz";
  callback = function(path, mt, sz)
    print("++++", path, mt, sz)
  end;
  recurse = true;
}

do return end

do return end

require"afx"
local findfile = m.A.findfile_t

print(findfile{
  file = "*./*";
  param = "ftz";
  callback = function(path, mt, sz)
    print(path, mt, sz)
  end;
  recurse = true;
})
end

return {
  load = load
}