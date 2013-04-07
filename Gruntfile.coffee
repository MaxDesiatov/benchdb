require('trace');

module.exports = (grunt) ->
  grunt.initConfig
    pkg: grunt.file.readJSON 'package.json'
    karma:
      continuous:
        configFile: './tests/karma.conf.coffee'
        singleRun: true

    browserify2:
      tests:
        entry: './tests/karma_tests.coffee'
        compile: './tests/karma_tests.js'
        debug: true
        beforeHook: (bundle) ->
          bundle.transform 'coffeeify'

  grunt.registerTask('test', 'nodeunit browserify2 karma')

  grunt.loadNpmTasks 'grunt-karma'
  grunt.loadNpmTasks 'grunt-browserify2'

  Error.stackTraceLimit = 50