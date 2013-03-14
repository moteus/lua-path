local lunit = require "lunit"
LUNIT_RUN = true

require 'test_wcs'
require 'test_fs'
require 'test_each'
require 'test'

lunit.run()