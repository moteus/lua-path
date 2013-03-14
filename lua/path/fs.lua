if false then
function PATH:size(P)
  local f, err = io.open(P, 'rb')
  if not f then return nil, err end
  local size, err = f:seek('end')
  f:close()
  if not size then return nil, err end
  return size
end

function PATH:tmpdir()
  if PATH.IS_WINDOWS then
    for _, p in ipairs{'TEMP', 'TMP'} do
      dir = os.getenv(p)
      if dir and dir ~= '' then
        return self:remove_dir_end(dir)
      end
    end
  end
  return self:dirname(os.tmpname())
end

function PATH:isfile(P)
  local f, err = io.open(P, 'rb')
  if f then f:close() end
  return not not f
end

function PATH:exists(P)
  return self:isfile(P)
end

end

local function pt(str) return str end

local function remove_impl_batch(fs, src_dir, mask, opt)
  if not opt then opt = {} end

  local accept    = opt.accept
  local onerror   = opt.error
  local chlen     = #fs.DIR_SEP
  local delay     = (opt.delay == nil) and true or false

  return fs.each_impl{file = src_dir .. fs.DIR_SEP .. mask,
    delay = delay; recurse = opt.recurse; reverse = true; param = "fm";
    callback = function(src, mode)
      if accept then
        local ok = accept(src, opt)
        if not ok then return end
      end

      local ok, err
      if mode == "directory" then ok, err = fs.rmdir(dst)
      else ok, err = fs.remove(src) end

      if not ok and onerror then
        if not onerror(err, src, opt) then -- break
          return true
        end
      end
    end;
  }
end

local function copy_impl_batch(fs, src_dir, mask, dst_dir, opt)
  if not opt then opt = {} end

  local overwrite = opt.overwrite
  local accept    = opt.accept
  local onerror   = opt.error
  local chlen     = #fs.DIR_SEP
  local count     = 0

  local ok, err = fs.each_impl{file = src_dir .. fs.DIR_SEP .. mask,
    delay = opt.delay; recurse = opt.recurse; param = "pnm";
    callback = function(path, name, mode)
      local rel = string.sub(path, #src_dir + chlen + 1)
      if #rel > 0 then rel = rel .. fs.DIR_SEP .. name else rel = name end
      local dst = dst_dir .. fs.DIR_SEP .. rel
      local src = path .. fs.DIR_SEP .. name

      if accept then
        local ok = accept(src, dst, opt)
        if not ok then return end
      end

      local ok, err
      if mode == "directory" then ok, err = fs.mkdir(dst)
      else ok, err = fs.copy(src, dst, not overwrite) end

      if not ok and onerror then
        if not onerror(err, src, dst, opt) then -- break
          return true
        end
      else
        count = count + 1
      end
    end;
  }
  if ok or err then return ok, err end
  return count
end


  -- If the file is to be moved to a different volume, the function simulates the move by using the CopyFile and DeleteFile functions.
  -- If the file is successfully copied to a different volume and the original file is unable to be deleted, the function succeeds leaving the source file intact.
  -- This value cannot be used with MOVEFILE_DELAY_UNTIL_REBOOT.
  MOVEFILE_COPY_ALLOWED           = 0x00000002;

  -- Reserved for future use.
  MOVEFILE_CREATE_HARDLINK        = 0x00000010;

  -- The system does not move the file until the operating system is restarted. The system moves the file immediately after AUTOCHK is executed, but before creating any paging files. Consequently, this parameter enables the function to delete paging files from previous startups.
  -- This value can be used only if the process is in the context of a user who belongs to the administrators group or the LocalSystem account.
  -- This value cannot be used with MOVEFILE_COPY_ALLOWED.
  -- Windows Server 2003 and Windows XP:  For information about special situations where this functionality can fail, and a suggested workaround solution, see Files are not exchanged when Windows Server 2003 restarts if you use the MoveFileEx function to schedule a replacement for some files in the Help and Support Knowledge Base.
  MOVEFILE_DELAY_UNTIL_REBOOT     = 0x00000004;


  -- The function fails if the source file is a link source, but the file cannot be tracked after the move. This situation can occur if the destination is a volume formatted with the FAT file system.
  MOVEFILE_FAIL_IF_NOT_TRACKABLE  = 0x00000020;


  -- If a file named lpNewFileName exists, the function replaces its contents with the contents of the lpExistingFileName file, provided that security requirements regarding access control lists (ACLs) are met. For more information, see the Remarks section of this topic.
  -- This value cannot be used if lpNewFileName or lpExistingFileName names a directory.
  MOVEFILE_REPLACE_EXISTING       = 0x00000001;


  -- The function does not return until the file is actually moved on the disk.
  -- Setting this value guarantees that a move performed as a copy and delete operation is flushed to disk before the function returns. The flush occurs at the end of the copy operation.
  -- This value has no effect if MOVEFILE_DELAY_UNTIL_REBOOT is set.
  MOVEFILE_WRITE_THROUGH          = 0x00000008;






local wcs = require "path.win32.wcs".load("ffi")
local _T  = wcs.ansitowcs
local _t  = wcs.wcstoansi
local function mkfile(P, data)
  local f, e = io.open(_t(P), "w+b")
  if not f then return nil, e end
  if data then assert(f:write(data)) end
  f:close()
  return P
end

_t,_T = pt, pt
fs = require "path.win32.fs".load("alien", "A")
-- fs = require "path.lfs.fs"

local src = _T[[F:\tmp\hello]]
local dst = _T[[G:\f]]
-- mkdir = fs.mkdir
-- -- mkdir(src)
-- print(fs.move(src, dst))


require"afx"
print(afx.movefile([[F:\tmp\*.*]], [[g:\tmp]],{recurse=true}))

