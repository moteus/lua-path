function prequire(...)
  local ok, mod = pcall(require, ...)
  if not ok then return mod, ... end
  return nil, mod
end

prequire"luacov"
local lunit = require "lunit"
LUNIT_RUN = true

require 'test_wcs'
require 'test_fs'
require 'test_each'
require 'test'

lunit.run()