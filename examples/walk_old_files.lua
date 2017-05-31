local path = require "path"
local date = require "date"

local function older_then(days)
  local now = date()
  return function (fname, ftime)
    return days <= date.diff(now, date(ftime):tolocal()):spandays()
  end
end

local function old_files_(mask, days, cmd)
  assert(days)
  assert(cmd)

  -- признак того что в директории есть файлы не поподающие под фильтр
  local has_more_files = false
  local filter = older_then(days)
  local last_fname, last_fdate
  path.each{file = mask, param = 'ft',
    recurse=false, skipdirs=true,
    callback = 
  function(fname, ftime)
    if filter(fname, ftime) then
      if not last_fdate then -- первый попавшийся файл
        last_fname, last_fdate = fname, date(ftime)
        return
      end

      -- перед этим уже бал найден файл
      local next_fname, next_fdate = fname, date(ftime)

      -- находим самый "старый" файл
      if last_fdate < next_fdate then
        last_fdate, next_fdate = next_fdate, last_fdate
        last_fname, next_fname = next_fname, last_fname
      end

      cmd(next_fname, false)
    else 
      -- в директории есть файлы которые поподают под маску и не поподают под фильтр
      has_more_files = true
    end
  end}
  if last_fname then cmd(last_fname, not has_more_files) end
end

--
-- @param mask - если первый символ '!', то поиск производится рекурсивно
-- @param days - количество дней после создания после которого файл считается старым
-- @param cmd  - команда обработки файла. В нее передается полный путь файла и 
--  признак того что файл является последним который подподает под маску в данной директории.
--  Гарантируется что если это последний файл, то он имеет самую позднюю дату (самый "свежий")
local function walk_old_files(mask, days, cmd)
  local is_recurse = mask:sub(1,1) == '!'

  if is_recurse then mask = mask:sub(2) end

  old_files_(mask,  days, cmd)

  if not is_recurse then return end

  local dir_mask, file_mask = path.splitpath(mask)
  path.each{file = path.join(dir_mask, '*'),
    recurse=true, skipdirs=false, skipfiles=true,
    callback= function(fname)
      if path.isdir(fname) then
        old_files_(path.join(fname, file_mask), days, cmd)
      end
    end
  }
end


return walk_old_files