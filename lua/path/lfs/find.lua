---
-- Implementation of afx.findfile

local string    = require "string"
local table     = require "table"
local coroutine = require "coroutine"
local PATH      = require "path.module"
local lfs       = require "lfs"

local function fs_foreach(path, match, cb, recursive)
  local dir_next, dir = lfs.dir(path)
  for name in dir_next, dir do if name ~= "." and name ~= ".." then
    local path_name = PATH.join(path, name)
    if match(path_name) then
      if cb(path_name) then if dir then dir:close() end return 'break' end
    end
    if recursive and PATH.isdir(path_name) then
      if 'break' == fs_foreach(path_name, match, cb, match) then
        if dir then dir:close() end
        return 'break'
      end
    end
  end end
  return true
end

local function filePat2rexPat(pat)
  local pat = "^" .. pat:gsub("%.","%%."):gsub("%*",".*"):gsub("%?", ".") .. "$"
  if PATH.IS_WINDOWS then pat = pat:upper() end
  return pat
end

local function match_pat(pat)
  pat = filePat2rexPat(pat)
  return PATH.IS_WINDOWS 
  and function(s) return nil ~= string.find(string.upper(s), pat) end
  or  function(s) return nil ~= string.find(s, pat) end
end

local attribs = {
  f = function(path) return PATH.fullpath(path) end;
  n = function(path) return PATH.basename(path) end;
  a = function(path) return PATH.fileattrib and PATH.fileattrib(path) or 0 end;
  z = function(path) return PATH.isdir(path) and 0 or PATH.size(path) end;
  t = function(path) return PATH.mtime(path) end;
  c = function(path) return PATH.ctime(path) end;
  l = function(path) return PATH.atime(path) end;
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
  local mask_match = match_pat(mask)

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

return{
  findfile_t = findfile_t
}