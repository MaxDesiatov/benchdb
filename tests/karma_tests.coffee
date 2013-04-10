suite = (require './common_tests.coffee')(require './browser_config.coffee')
nodeunit.run
  basicSuite: nodeunit.testCase suite.basicSuite
  complexSuite: nodeunit.testCase suite.complexSuite