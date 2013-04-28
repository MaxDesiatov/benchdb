path = require 'path'

module.exports = (karma) ->
  proxiesConfig = require path.resolve __dirname, './node_config'

  karma.configure
    # base path, that will be used to resolve files and exclude
    basePath: ''

    # list of files / patterns to load in the browser
    files: [
        '../../node_modules/karma-nodeunit/lib/nodeunit.js',
        '../../node_modules/karma-nodeunit/lib/adapter.js',
        'karma_dist.js'
    ]

    # list of files to exclude
    exclude: []

    # test results reporter to use
    # possible values: dots || progress || growl
    reporters: ['progress']

    # web server port
    port: 8080

    # cli runner port
    runnerPort: 9100

    # enable / disable colors in the output (reporters and logs)
    colors: true

    # level of logging
    # possible values: LOG_DISABLE || LOG_ERROR || LOG_WARN || LOG_INFO || LOG_DEBUG
    logLevel: karma.LOG_INFO

    # enable / disable watching file and executing tests whenever any file changes
    autoWatch: false

    # browser-request seems to be broken in firefox
    browsers: ['Safari']

    proxies:  {
        '/couch': 'http://' + proxiesConfig.host + ':' + proxiesConfig.port
    }
    # If browser does not capture in given timeout [ms], kill it
    captureTimeout: 5000

    # Continuous Integration mode
    # if true, it capture browsers, run tests and exit
    singleRun: false

    plugins: [
      'karma-chrome-launcher',
      'karma-safari-launcher',
      'karma-firefox-launcher',
    ]