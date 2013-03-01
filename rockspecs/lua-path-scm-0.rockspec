package = "lua-path"
version = "scm-0"
source = {
  url = "https://github.com/moteus/lua-path/archive/master.zip",
  dir = "lua-path-master",
}

description = {
  summary = "File system path manipulation library",
  detailed = [[
  ]],
  homepage = "https://github.com/moteus/lua-path",
  -- license = ""
}

dependencies = {
  "lua >= 5.1",
  "lfs >= 1.4",
}

build = {
  type = "builtin",
  copy_directories = {
    "test",
  },
  modules = {
    ["path"                        ] = "lua/path.lua",
    ["path.findfile"               ] = "lua/path/findfile.lua",
    ["path.module"                 ] = "lua/path/module.lua",
  }
}



