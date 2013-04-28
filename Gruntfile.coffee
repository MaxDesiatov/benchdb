path = require 'path'

module.exports = (grunt) ->
  # load all grunt tasks
  require('matchdep').filterDev('grunt-*').forEach(grunt.loadNpmTasks)

  grunt.initConfig
    pkg: grunt.file.readJSON 'package.json'
    nodeunit:
      all: ['dist/tests/node_tests.js']
    karma:
      continuous:
        configFile: path.resolve __dirname, './dist/tests/karma.js'
        singleRun: true

    browserify:
      karma:
        src: ['dist/tests/karma_tests.js']
        dest: 'dist/tests/karma_dist.js'

    clean:
      dist: ['dist']

    coffee:
      dist:
        expand: true
        src: ['{,*/}*.coffee', '!Gruntfile.coffee']
        dest: 'dist'
        ext: '.js'

    copy:
      dist:
        files: [{
          expand: true
          dest: 'dist'
          src: [ 'LICENSE', 'README.md', 'package.json' ]
        }]

  grunt.registerTask 'dist', ['clean', 'coffee']
  grunt.registerTask 'publish', ['dist', 'copy']
  grunt.registerTask 'karma-test', ['dist', 'browserify', 'karma']
  grunt.registerTask 'test', ['dist', 'nodeunit', 'browserify', 'karma']
