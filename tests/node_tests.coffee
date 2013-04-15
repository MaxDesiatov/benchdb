common = (require './common_tests.coffee')(require './node_config.coffee')

async = require 'async'
_ = require 'underscore'
streamEqual = require 'stream-equal'
fs = require 'fs'
path = require 'path'
Tempfile = require 'temporary/lib/file'
Tempdir = require 'temporary/lib/dir'
Type = require '../benchdb.coffee'
weak = require 'weak'

testdoc = _id: 'testdoc', testprop: 41
testid = 'testid'
testval = 'testval'

minBytes = 1024 * 1024 * 1
maxBytes = 1024 * 1024 * 10

generateRandomFile = (cb) ->
  file = new Tempfile
  endRandom = _.random minBytes, maxBytes
  devRandom = fs.createReadStream '/dev/random', { start: 0, end: endRandom }
  devRandom.on 'end', -> cb null, file.path
  devRandom.pipe fs.createWriteStream file.path

common.complexSuite.testAttachment = (test) ->
  uploadedFile = null
  downloadedFile = null
  revisionBeforeUpload = null
  async.waterfall [
    ((cb) => @testDb.create testdoc, cb),
    ((res, cb) =>
      test.ok res.ok, 'document creation test failed'
      test.equals res.id, testdoc._id, "document creation id comparison
              test failed"
      @testDb.retrieve testdoc, cb),
    ((res, cb) =>
      test.equals res.testprop, testdoc.testprop, "document creation property
              comparison test failed"
      @testDb.modify _(testdoc).extend(testprop: 42, _rev: res._rev), cb)
    ((res, cb) =>
      test.ok res.ok, 'document modification #1 test failed'
      test.ok res.rev?, 'document modification #2 test failed'
      revisionBeforeUpload = res.rev
      generateRandomFile cb),
    ((res, cb) =>
      uploadedFile = res
      updatedDoc = _(testdoc).extend _rev: revisionBeforeUpload
      @testDb.uploadAttachment updatedDoc, res, path.basename(res), cb),
    ((res, cb) =>
      test.ok res.ok
      test.ok res.id?
      test.equals res.id, testdoc._id
      @testDb.retrieve testdoc, cb),
    ((res, cb) =>
      test.equals res.testprop, 42, "document modification property comparison
              test failed"
      dir = (new Tempdir).path
      test.ok res._attachments?
      filename = Object.keys(res._attachments)[0]
      downloadedFile = path.join dir, filename
      @testDb.downloadAttachment res, filename, dir, cb),
    ((res, cb) ->
      uploadedStream = fs.createReadStream uploadedFile
      downloadedStream = fs.createReadStream downloadedFile
      streamEqual uploadedStream, downloadedStream, cb),
    ((res, cb) ->
      test.ok res
      fs.unlink uploadedFile
      fs.unlink downloadedFile
      cb())], (err) ->
                test.ok not err, 'error absence final callback test failed'
                test.done()

common.complexSuite.testTypeCache = (test) ->
  t = new Type @testDb, 'testtype'
  t.instance true, testid, (err, res1) ->
    test.equals err, null, 'type cache error absence test failed'
    test.deepEqual weak.get(t.cache[testid]), res1,
      'type cache deep equality test failed'
    res1.data.testprop = testval
    t.instance true, testid, (err, res2) ->
      test.equals res2.data.testprop, testval,
        'type cache singleton instance test failed'
      test.done()

module.exports = common