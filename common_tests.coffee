db = require './common'
a = require 'async'
_ = require 'underscore'

testdoc = { _id: 'testdoc' }

steps = (test, testDb) ->
  a.waterfall [
    _(testDb.exists).bind(testDb),
    ((res, cb) ->
      test.equals res.error, 'not_found', 'db exists test #1 failed'
      test.equals res.reason, 'no_db_file', 'db exists test #2 failed'
      testDb.existsBool cb),
    ((res, cb) ->
      test.ok not res, 'db exists test #3 failed'
      testDb.createItself cb),
    ((res, cb) ->
      test.ok res.ok, 'db created test #1 failed'
      testDb.existsBool cb)
    ((res, cb) ->
      test.ok res, 'db created test #2 failed'
      testDb.retrieveAll cb),
    ((res, cb) ->
      test.equals res.total_rows, 0, 'newly created db row count test failed'
      testDb.create testdoc, cb),
    ((res, cb) ->
      test.ok res.ok, 'document creation test failed'
      test.equals res.id, testdoc._id, "document creation id comparison
        test failed"
      testDb.modify _(testdoc).extend(testprop: 42, _rev: res.rev), cb)
    ((res, cb) ->
      test.ok res.ok, 'document modification test failed'
      testDb.removeItself cb),
    ((res, cb) ->
      test.ok res.ok, 'newly created db removed test failed'
      cb())], -> test.done()

chars = 'abcdefghijklmnopqrstuvwxyz'

generateDbName = (host, port, endCb) ->
  name = chars[_.random(0, chars.length - 1)]
  exists = false
  a.whilst (-> exists), ((cb) ->
    testDb = new db host, port, name
    testDb.exists (error, res) ->
      exists = res.db_name is name
      name += chars[_.random(0, chars.length - 1)]
      cb()), -> endCb name

module.exports =
  testFullUrl: (test) ->
    generateDbName '127.0.0.1', 5984, (dbName) ->
      testDb = new db "http://127.0.0.1:5984/#{ dbName }"
      test.equals testDb.root, "http://127.0.0.1:5984/#{ dbName }/"
      steps test, testDb

  testSplitUrl: (test) ->
    generateDbName '127.0.0.1', 5984, (dbName) ->
      testDb = new db '127.0.0.1', 5984, dbName
      test.equals testDb.root, "http://127.0.0.1:5984/#{ dbName }/"
      steps test, testDb
