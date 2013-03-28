module.exports = (grunt) ->
  grunt.initConfig
    pkg: grunt.file.readJSON 'package.json'

  grunt.registerTask 'default', 'Log some stuff.', ->
    grunt.log.write('Logging some stuff...').ok()
