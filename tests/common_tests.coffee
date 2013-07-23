db = require '../api'
Type = require '../benchdb'
async = require 'async'
_ = require 'underscore'

testdoc = _id: 'testdoc', testprop: 41, type: 'blahblah'
testtype = 'testtype'

basicSteps = (test, testDb) ->
  async.waterfall [
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
      testDb.removeItself cb),
    ((res, cb) ->
      test.ok res.ok, 'db removal test #1 failed'
      testDb.existsBool cb),
    ((res, cb) ->
      test.ok not res, 'db removal test #2 failed'
      cb())], (err) ->
                test.ok not err, 'error absence final callback test failed'
                test.done()

chars = 'abcdefghijklmnopqrstuvwxyz'
randChar = -> chars[_.random 0, chars.length - 1]

generateDbName = (url, endCb) ->
  name = randChar()
  exists = false
  async.whilst (-> exists), ((cb) ->
    testDb = new db "#{ url }#{ name }"
    testDb.exists (error, res) ->
      exists = res.db_name is name
      name += randChar()
      cb()), -> endCb name

module.exports = (config) ->
  couchUrl = "http://#{config.host}:#{config.port}#{config.pathPrefix}"
  dbUrl = (dbName) -> "#{ couchUrl }#{ dbName }"

  basicSuite:
    testFullUrl: (test) ->
      generateDbName couchUrl, (dbName) ->
        fullUrl = dbUrl dbName
        testDb = new db fullUrl
        test.equals testDb.root, "#{fullUrl}/", 'db root url test failed'
        basicSteps test, testDb

    testSplitUrl: (test) ->
      generateDbName couchUrl, (dbName) ->
        fullUrl = dbUrl dbName
        testDb = new db config.host, config.port, config.pathPrefix, dbName
        test.equals testDb.root, "#{fullUrl}/", 'db root url test failed'
        basicSteps test, testDb

    testCheckExists: (test) ->
      generateDbName couchUrl, (dbName) ->
        testDb = new db dbUrl(dbName)
        async.waterfall [
          _(testDb.existsBool).bind(testDb),
          ((res, cb) ->
            test.ok not res, 'generateDbName test failed'
            testDb.checkExists cb),
          _(testDb.existsBool).bind(testDb),
          ((res, cb) ->
            test.ok res, 'checkExists test failed'
            testDb.removeItself cb),
          ((res, cb) ->
            test.ok res.ok, 'checkExists cleanup test #1 failed'
            testDb.existsBool cb),
          ((res, cb) ->
            test.ok not res, 'checkExists cleanup test #2 failed'
            cb())], -> test.done()

  complexSuite:
    setUp: (cb) ->
      generateDbName couchUrl, (dbName) =>
        @testDb = new db config.host, config.port, config.pathPrefix, dbName
        @testDb.createItself cb

    tearDown: (cb) ->
      @testDb.removeItself cb

    testExists: (test) ->
      @testDb.existsBool (err, res) ->
        test.ok res, 'db exists test failed'
        test.done()

    testEmpty: (test) ->
      @testDb.retrieveAll (err, res) ->
        test.ok res? and _.isFinite res.total_rows,
          'newly created db row count test #1 failed'
        if res? and _.isFinite res.total_rows
          test.equals res.total_rows, 0,
            'newly created db row count test #2 failed'
        test.done()

    testDocument: (test) ->
      testdocInstance = _.clone testdoc
      async.waterfall [
        ((cb) => @testDb.create testdocInstance, cb),
        ((res, cb) =>
          test.ok res.ok, 'document creation test failed'
          test.equals res.id, testdocInstance._id, "document creation id comparison
            test failed"
          @testDb.retrieve testdocInstance, cb),
        ((res, cb) =>
          test.equals res.testprop, testdoc.testprop,
            "document creation property comparison test failed"
          _(testdocInstance).extend(testprop: 42, _rev: res._rev)
          @testDb.modify testdocInstance, cb),
        ((res, cb) =>
          test.ok res.ok, 'document modification #1 test failed'
          test.ok res.rev?, 'document modification #2 test failed'
          @testDb.remove  _(testdocInstance).extend(_rev: res.rev), cb),
        ((res, cb) =>
          test.ok res.ok, 'document removal test #1 failed'
          @testDb.existsBool testdocInstance, cb),
        ((res, cb) =>
          test.ok not res, 'document removal test #2 failed'
          cb())],
        (err) ->
          test.ok not err, 'error absence final callback test failed'
          test.done()

    testUuids: (test) ->
      async.waterfall [
        ((cb) => @testDb.uuids cb),
        ((res, cb) =>
          test.ok _.isArray(res), 'uuids type test failed'
          test.equals res.length, 1, 'uuids length test failed'
          @testDb.uuids 5, cb),
        ((res, cb) ->
          test.equals res.length, 5, 'uuids length test #2'
          cb())],
        (err) ->
          test.ok not err, 'error absence final callback test failed'
          test.done()

    testTypeApi: (test) ->
      t = new Type @testDb, 'testtype'
      t.api = 'mangle-schmangle'
      test.equals t.api, @testDb, 'Test.api property freeze test failed'
      test.done()

    testInstanceUuidGenerated: (test) ->
      t = new Type @testDb, 'testtype'
      t.instance false, (err, res) ->
        test.equals err, null,
          'instance uuid generation error absence test failed'
        test.ok _.isString(res.data._id),
          'instance uuid generation id type test failed'
        test.ok res.data._id.length > 0,
          'instance uuid generation id length test failed'
        test.done()

    testInstanceType: (test) ->
      t = new Type @testDb, testtype
      t.instance false, (err, res) ->
        test.equals err, null,
          'created instance type generation error absence test failed'
        test.equals res.data.type, testtype, 'created instance type test failed'
        test.done()

    testTypeWithoutName: (test) ->
      test.throws (-> new Type @testDb)
      test.throws (-> new Type @testDb, '')
      test.done()

    testInstanceSaveRefresh: (test) ->
      t = new Type @testDb, testtype
      t.instance false, (err, res) ->
        test.equals err, null, 'save instance error absence test #1 failed'
        oldid = res.data._id
        _(res.data).extend testdoc
        test.equals res.data._id, oldid,
          'instance data id is immutable test failed'
        test.equals res.id, oldid,
          'instance id is consistent with data test failed'
        test.equals res.data.type, testtype,
          'instance data type is immutable test failed'
        res.save (err) ->
          test.equals err, null, 'save instance error absence test #2 failed'
          t.instance false, oldid, (err, newRes) ->
            test.equals err, null, 'save instance error absence test #3 failed'
            test.equals newRes.data.testprop, undefined,
              'save instance empty property test failed'
            newRes.refresh (err) ->
              test.equals err, null,
                'save instance error absence test #4 failed'
              test.equals newRes.data.testprop, 41,
                'save instance refresh property test failed'
              test.equals newRes.data.type, testtype,
                'instance data type is saved test failed'
              test.done()

    testInstanceRemoveRefresh: (test) ->
      t = new Type @testDb, testtype
      t.instance false, (err, res) ->
        res.save ->
          res.refresh (err, savedData) ->
            test.deepEqual res.data, savedData,
              'remove instance save test failed'
            res.remove (err) ->
              test.equals err, null, 'remove instance error absence test failed'
              res.refresh (err, notFoundRes) ->
                test.equals err, null,
                  'remove instance error absence test #2 failed'
                test.ok _.isObject(notFoundRes),
                  'remove instance refresh response is object test failed'
                test.equals notFoundRes.error, 'not_found',
                  'remove instance refresh response error test failed'
                test.equals notFoundRes.reason, 'deleted',
                  'remove instance refresh response error reason test failed'
                test.done()

    testTypeAll: (test) ->
      tt = new Type @testDb, testtype
      dt = new Type @testDb, 'dummytype'
      iterator = (t) -> (n, next) -> t.instance false, (dummy, res) ->
        res.save (err) -> next err, res.id
      async.times 5, iterator(dt), ->
        async.times 10, iterator(tt), (err, docIds) ->
          tt.all (err, res) ->
            docs = res.instances
            test.ok _.isArray(docs), 'all type instances result type test failed'
            test.equals docs.length, 10,
              'all type instances result length test failed'
            i = _.intersection (doc.id for doc in docs), docIds
            test.equals i.length, 10, 'all type instances result ids test failed'
            test.done()

    testTypeFilterByFieldValue: (test) ->
      t = new Type @testDb, testtype
      iterator = (n, next) -> t.instance false, (dummy, res) ->
        res.data.filterField = n
        res.data.filterAnotherField = n % 2
        res.save (err) -> next err, res.id
      async.times 5, iterator, ->
        t.filterByField 'filterField', 3, (err, res) ->
          docs = res.instances
          test.equals docs.length, 1, 'filterByField value length test failed'
          if docs.length? and docs.length > 0
            doc = docs[0]
            doc.refresh (err, res) ->
              test.equals err, null,
                'filterByField value error absence test failed'
              test.equals doc.data.filterField, 3,
                'filterByField value equality test failed'
              t.filterByField 'filterAnotherField', 0, (err, res) ->
                docs = res.instances
                test.equals docs.length, 3,
                  'filterByField value length test #2 failed'
                test.done()
          else
            test.done()

    testTypeFilterByFieldOpts: (test) ->
      t = new Type @testDb, testtype
      iterator = (n, next) -> t.instance false, (dummy, res) ->
        res.data.filterField = n
        res.save (err) -> next err, res.id
      async.times 5, iterator, ->
        t.filterByField {startkey: 2, endkey: 4}, 'filterField', (err, res) ->
          docs = res.instances
          test.equals docs.length, 3, 'filterByField opts length test failed'
          async.each docs, ((doc, next) -> doc.refresh next), (err) ->
            test.equal err, null,
              'filterByField values error absence test failed'
            filterFieldValues =
              _.chain(docs).pluck('data').pluck('filterField').value()
            test.deepEqual filterFieldValues, [2, 3, 4],
              'filterByField values equality test failed'
            test.done()

    testTypeFilterByFieldSort: (test) ->
      t = new Type @testDb, testtype
      iterator = (n, next) -> t.instance false, (dummy, res) ->
        res.data.filterField = n
        res.data.filterAnotherField = n % 2
        res.save (err) -> next err, res.id
      async.times 5, iterator, ->
        t.filterByField {
          sort: ['filterField']
          descending: true
        }, 'filterAnotherField', 0, (err, res) ->
          docs = res.instances
          test.equals docs.length, 3, 'filterByField sort length test failed'
          async.each docs, ((doc, next) -> doc.refresh next), (err) ->
            test.equal err, null,
              'filterByField values error absence test failed'
            filterFieldValues =
              _.chain(docs).pluck('data').pluck('filterField').value()
            test.deepEqual filterFieldValues, [4, 2, 0],
              'filterByField with sort values equality test failed'
            test.done()

    testTypeFilterByFields: (test) ->
      t = new Type @testDb, testtype
      iterator = (n, next) -> t.instance false, (dummy, res) ->
        res.data.filterField = n
        res.data.filterThree = n % 3
        res.data.filterFour = n % 4
        res.save (err) -> next err, res.id
      async.times 50, iterator, ->
        t.filterByFields {
          sort: ['filterField'],
          include_docs: true
        }, {filterThree: 0, filterFour: 0}, (err, res) ->
          docs = res.instances
          test.equals docs.length, 5, 'filterByFields values length test failed'
          filterFieldValues =
            _.chain(docs).pluck('data').pluck('filterField').value()
          test.deepEqual filterFieldValues, [0, 12, 24, 36, 48],
            'filterByFields values equality test failed'
          test.done()
