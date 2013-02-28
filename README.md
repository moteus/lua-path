Usage:
```lua
local PATH = require "path"

-- suppose we run on windows
assert(PATH.IS_WINDOWS)

-- we can use system dependet function
print(PATH.user_home())  -- C:\Documents and Settings\Admin
print(PATH.currentdir()) -- C:\lua\5.1

-- but we can use specific system path notation
local ftp_path = PATH.new('/')
print(ftp_path:join("/root", "some", "dir")) -- /root/some/dir

-- All functions specific to system will fail
assert(not pcall( ftp_path:currentdir() ) )
```