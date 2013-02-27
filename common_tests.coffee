db = require('./common').DB

actualSteps = (test, testDb) ->
  testDb.exists (res) ->
    test.equals res.error, "not_found", "db exists test #1 failed"
    test.equals res.reason, "no_db_file", "db exists test #2 failed"

    testDb.createItself (res) ->
      test.ok res.ok, "db created test failed"

      testDb.retrieveAll (res) ->
        test.equals res.total_rows, 0, "newly created db row count test failed"

        testDb.removeItself (res) ->
          test.ok res.ok, "newly created db removed test failed"

          test.done()

module.exports =
  testFullUrl: (test) ->
    testDb = new db 'http://127.0.0.1:5984/testdb'
    actualSteps test, testDb

  testSplitUrl: (test) ->
    testDb = new db '127.0.0.1', 5984, 'testdb'
    actualSteps test, testDb
