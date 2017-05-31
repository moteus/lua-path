local path = require "path"

local function is_empty_dir(p)
  local ok = path.each(path.join(p, '*.*'), function()
    return true
  end)
  return not ok
end

local function walk_empty_dirs(p, fn)
  local is_recurse = p:sub(1,1) == '!'
  if is_recurse then p = p:sub(2) end

  path.each(path.join(p, '*'), fn, {
    skipfiles=true, skipdirs=false, recurse=is_recurse, filter=is_empty_dir,
  })
end

return walk_empty_dirs