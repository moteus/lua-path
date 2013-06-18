
function prequire(...)
  local ok, mod = pcall(require, ...)
  if ok then return mod, ... end
  return nil, mod
end

local lfs = prequire "lfs"

print("------------------------------------")
print("Lua version: " .. (_G.jit and _G.jit.version or _G._VERSION))
print("LFS version: " .. (lfs and (lfs._VERSION or "(unknown)") or "(not found)")   )
print("------------------------------------")
print("")

prequire"luacov"

local HAS_RUNNER = not not lunit
local lunit = require "lunit"
LUNIT_RUN = true

require 'test_wcs'
require 'test_fs'
require 'test_each'
require 'test'

if not HAS_RUNNER then lunit.run() end