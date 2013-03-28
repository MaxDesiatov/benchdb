path = require 'path'
_ = require 'underscore'
async = require 'async'
request = require('request').defaults json: true
fs = require 'fs'

class DB
  docIdOk = (docId) -> _.isString(docId) or _.isNumber(docId)
  wrapCb = (cb) -> (err, _, body) -> cb err, body

  constructor: (host, port, dbname) ->
    @alwaysCheckExists = false
    if port? and dbname?
      @root = "http://#{ host }:#{ port }/#{ dbname }/"
    else if _.isString host
        @root = host
        if _.last(@root) isnt '/'
          @root = "#{ @root }/"
    else
      throw 'BenchDB.constructor: attempt to create a DB without name and host'

    @validationDocUrl = "#{ @root }_design/validation"

  exists: (doc, cb) ->
    if _.isObject(doc) and docIdOk(doc._id)
      request "#{ @root }#{ doc._id }", wrapCb cb
    else if docIdOk(doc)
      request "#{ @root }#{ doc }", wrapCb cb
    else if _.isFunction doc
      request @root, wrapCb doc
    else
      throw 'BenchDB.exists: no document id and/or callback specified'

  existsBool: (doc, cb) ->
    if _.isFunction doc
      @exists (error, res) -> doc(error, res.error isnt 'not_found')
    else
      @exists doc, (error, res) -> cb(error, res.error isnt 'not_found')

  checkExists: (endCb) ->
    async.waterfall [
      ((cb) =>
        @existsBool cb),
      ((res, cb) =>
        if res
          cb 'ok'
        else
          @createItself cb),
      ((res, cb) ->
        if res.ok
          cb 'ok'
        else
          cb res)],
      (error) ->
        if error is 'ok'
          endCb null
        else
          endCb error

  retrieveAll: (cb) ->
    request "#{ @root }_all_docs?include_docs=true", wrapCb cb

  retrieve: (doc, cb) ->
    if _.isObject(doc) and docIdOk(doc._id)
      request "#{ @root }#{ doc._id }", wrapCb cb
    else if docIdOk(doc)
      request "#{ @root }#{ doc }", wrapCb cb
    else
      throw 'BenchDB.retrieve: no document id and/or callback specified'

  createItself: (cb) ->
    request.put @root, wrapCb cb

  create: (doc, cb) ->
    if _.isObject(doc) and docIdOk(doc._id)
      request.put "#{ @root }#{ doc._id }", json: doc, wrapCb cb
    else if docIdOk(doc)
      request.put "#{ @root }#{ doc }", wrapCb cb
    else if _.isFunction cb
      request.post @root, json: doc, wrapCb cb
    else
      throw 'BenchDB.create: no document id and/or callback specified'

  removeItself: (cb) ->
    request.del @root, wrapCb cb

  remove: (doc, cb) ->
    if _.isObject(doc) and docIdOk(doc._id)
      request.del "#{ @root }#{ doc._id }", wrapCb cb
    else if docIdOk doc
      request.del "#{ @root }#{ doc }", wrapCb cb
    else
      throw 'BenchDB.remove: no document id and/or callback specified'

  modify: (doc, cb) ->
    if _.isObject(doc) and docIdOk(doc._id)
      request.put "#{ @root }#{ doc._id }", json: doc, wrapCb cb
    else
      throw 'BenchDB.modify: no document id and/or callback specified'

  downloadAttachment: (doc, filename, directory, cb) ->
    if docIdOk doc._id
      url = "#{ @root }#{ doc._id }/#{ filename }"
      filepath = path.join(directory, filename)
      request(url, wrapCb cb).pipe fs.createWriteStream filepath
    else
      throw 'BenchDB.downloadAttachment: no document id specified'

  uploadAttachment: (doc, filepath, filename, cb) ->
    if docIdOk doc._id
      url = "#{ @root }#{ doc._id }/#{ filename }?rev=#{ doc._rev }"
      fs.createReadStream(filepath).pipe request.put url, wrapCb cb
      true
    else
      throw 'BenchDB.attachFile: no document id specified'

module.exports = DB
