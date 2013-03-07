local lunit    = require "lunit"
local skip     = function (msg) return function() lunit.fail("#SKIP: " .. msg) end end
local IS_LUA52 = _VERSION >= 'Lua 5.2'

local TEST_CASE = function (name)
  if not IS_LUA52 then
    module(name, package.seeall, lunit.testcase)
    setfenv(2, _M)
  else
    return lunit.module(name, 'seeall')
  end
end

return {
  TEST_CASE = TEST_CASE;
  skip      = skip;
}