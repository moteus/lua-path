local ffi = require "ffi"

local C = ffi.C

local function pcdef(...)
  local ok, err = pcall( ffi.cdef, ... )
  if not ok then return nil, err end
  return err
end

local function pack(n, str)
  return [[
  #pragma pack(push)
  #pragma pack(1)
  ]] .. str ..[[
  #pragma pack(pop)
  ]]
end

ffi.cdef [[
  static const int MAX_PATH = 260;
  typedef uint32_t DWORD;
  typedef char    CHAR;
  typedef wchar_t WCHAR;
]]

pcdef(pack(1, [[ // GET_FILEEX_INFO_LEVELS
  typedef enum _GET_FILEEX_INFO_LEVELS { 
    GetFileExInfoStandard,
    GetFileExMaxInfoLevel 
  } GET_FILEEX_INFO_LEVELS;
]]))

pcdef(pack(1, [[ // FILETIME
  typedef struct _FILETIME {
    DWORD dwLowDateTime;
    DWORD dwHighDateTime;
  } FILETIME, *PFILETIME;
]]))

pcdef(pack(1, [[ // WIN32_FILE_ATTRIBUTE_DATA
  typedef struct _WIN32_FILE_ATTRIBUTE_DATA {
    DWORD    dwFileAttributes;
    FILETIME ftCreationTime;
    FILETIME ftLastAccessTime;
    FILETIME ftLastWriteTime;
    DWORD    nFileSizeHigh;
    DWORD    nFileSizeLow;
  } WIN32_FILE_ATTRIBUTE_DATA, *PWIN32_FILE_ATTRIBUTE_DATA;
]]))

pcdef(pack(1, [[ // WIN32_FIND_DATAA
  typedef struct _WIN32_FIND_DATAA {
    DWORD    dwFileAttributes;
    FILETIME ftCreationTime;
    FILETIME ftLastAccessTime;
    FILETIME ftLastWriteTime;
    DWORD    nFileSizeHigh;
    DWORD    nFileSizeLow;
    DWORD    dwReserved0;
    DWORD    dwReserved1;
    CHAR     cFileName[MAX_PATH];
    CHAR     cAlternateFileName[14];
  } WIN32_FIND_DATAA, *PWIN32_FIND_DATAA;
]]))

pcdef(pack(1, [[ // WIN32_FIND_DATAW
  typedef struct _WIN32_FIND_DATAW {
    DWORD    dwFileAttributes;
    FILETIME ftCreationTime;
    FILETIME ftLastAccessTime;
    FILETIME ftLastWriteTime;
    DWORD    nFileSizeHigh;
    DWORD    nFileSizeLow;
    DWORD    dwReserved0;
    DWORD    dwReserved1;
    WCHAR    cFileName[MAX_PATH];
    WCHAR    cAlternateFileName[14];
  } WIN32_FIND_DATAW, *PWIN32_FIND_DATAW;
]]))

local CTYPES = {
  DWORD     = ffi.typeof("DWORD");
  PCHAR     = ffi.typeof("CHAR*");
  PWCHAR    = ffi.typeof("WCHAR*");
  VLA_CHAR  = ffi.typeof("CHAR[?]");
  VLA_WCHAR = ffi.typeof("WCHAR[?]");

  WIN32_FILE_ATTRIBUTE_DATA = ffi.typeof("WIN32_FILE_ATTRIBUTE_DATA");
  FILETIME                  = ffi.typeof("FILETIME");
  WIN32_FIND_DATAA          = ffi.typeof("WIN32_FIND_DATAA");
  WIN32_FIND_DATAW          = ffi.typeof("WIN32_FIND_DATAW");
}

local c2lua 
c2lua = {

  WIN32_FILE_ATTRIBUTE_DATA = function(s) return {
    dwFileAttributes = s.dwFileAttributes;
    ftCreationTime   = {s.ftCreationTime.dwLowDateTime,   s.ftCreationTime.dwHighDateTime};
    ftLastAccessTime = {s.ftLastAccessTime.dwLowDateTime, s.ftLastAccessTime.dwHighDateTime};
    ftLastWriteTime  = {s.ftLastWriteTime.dwLowDateTime,  s.ftLastWriteTime.dwHighDateTime};
    nFileSize        = {s.nFileSizeLow,                   s.nFileSizeHigh};
  }end;

  WIN32_FIND_DATAA = function(s) 
    local res = c2lua.WIN32_FILE_ATTRIBUTE_DATA(s)
    res.cFileName = ffi.string(s.cFileName);
    return res
  end;

  WIN32_FIND_DATAW = function(s)
    local res = c2lua.WIN32_FILE_ATTRIBUTE_DATA(s)
    local pstr = ffi.cast(CTYPES.PCHAR, s.cFileName)
    local str = ffi.string(pstr, C.MAX_PATH * 2)
    res.cFileName = string.gsub(str,  "%z%z.*$", "");
    return res
  end;

}

local _M = {
  CTYPES = CTYPES;
  CTYPE2LUA = c2lua;

  FILE_ATTRIBUTE_ARCHIVE             = 0x20;    -- A file or directory that is an archive file or directory. Applications typically use this attribute to mark files for backup or removal . 
  FILE_ATTRIBUTE_COMPRESSED          = 0x800;   -- A file or directory that is compressed. For a file, all of the data in the file is compressed. For a directory, compression is the default for newly created files and subdirectories.
  FILE_ATTRIBUTE_DEVICE              = 0x40;    -- This value is reserved for system use.
  FILE_ATTRIBUTE_DIRECTORY           = 0x10;    -- The handle that identifies a directory.
  FILE_ATTRIBUTE_ENCRYPTED           = 0x4000;  -- A file or directory that is encrypted. For a file, all data streams in the file are encrypted. For a directory, encryption is the default for newly created files and subdirectories.
  FILE_ATTRIBUTE_HIDDEN              = 0x02;    -- The file or directory is hidden. It is not included in an ordinary directory listing.
  FILE_ATTRIBUTE_INTEGRITY_STREAM    = 0x8000;  -- The directory or user data stream is configured with integrity (only supported on ReFS volumes). It is not included in an ordinary directory listing. The integrity setting persists with the file if it's renamed. If a file is copied the destination file will have integrity set if either the source file or destination directory have integrity set. (This flag is not supported until Windows Server 2012.)
  FILE_ATTRIBUTE_NORMAL              = 0x80;    -- A file that does not have other attributes set. This attribute is valid only when used alone.
  FILE_ATTRIBUTE_NOT_CONTENT_INDEXED = 0x2000;  -- The file or directory is not to be indexed by the content indexing service.
  FILE_ATTRIBUTE_NO_SCRUB_DATA       = 0x20000; -- The user data stream not to be read by the background data integrity scanner (AKA scrubber). When set on a directory it only provides inheritance. This flag is only supported on Storage Spaces and ReFS volumes. It is not included in an ordinary directory listing. This flag is not supported until Windows 8 and Windows Server 2012.
  FILE_ATTRIBUTE_OFFLINE             = 0x1000;  -- The data of a file is not available immediately. This attribute indicates that the file data is physically moved to offline storage. This attribute is used by Remote Storage, which is the hierarchical storage management software. Applications should not arbitrarily change this attribute.
  FILE_ATTRIBUTE_READONLY            = 0x01;    -- A file that is read-only. Applications can read the file, but cannot write to it or delete it. This attribute is not honored on directories. For more information, see You cannot view or change the Read-only or the System attributes of folders in Windows Server 2003, in Windows XP, in Windows Vista or in Windows 7.
  FILE_ATTRIBUTE_REPARSE_POINT       = 0x400;   -- A file or directory that has an associated reparse point, or a file that is a symbolic link.
  FILE_ATTRIBUTE_SPARSE_FILE         = 0x200;   -- A file that is a sparse file.
  FILE_ATTRIBUTE_SYSTEM              = 0x04;    -- A file or directory that the operating system uses a part of, or uses exclusively.
  FILE_ATTRIBUTE_TEMPORARY           = 0x100;   -- A file that is being used for temporary storage. File systems avoid writing data back to mass storage if sufficient cache memory is available, because typically, an application deletes a temporary file after the handle is closed. In that scenario, the system can entirely avoid writing the data. Otherwise, the data is written after the handle is closed.
  FILE_ATTRIBUTE_VIRTUAL             = 0x10000; 
}

return _M
