suite = (require './common_tests.coffee')(require './browser_config.coffee')

Type = require '../benchdb.coffee'
_ = require 'underscore'

suite.complexSuite.testTypeCacheFrozen = (test) ->
  t = new Type @testDb, 'testtype'
  t.cache = a: 1, b: 2, c: 3
  test.ok _.isEmpty t.cache
  test.done()

nodeunit.run
  basicSuite: nodeunit.testCase suite.basicSuite
  complexSuite: nodeunit.testCase suite.complexSuite