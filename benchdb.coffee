path = require 'path'
_ = require 'underscore'
async = require 'async'
request = require('request').defaults json: true
fs = require 'fs'

apiOk = (api) ->
  if not api instanceOf DB
    throw 'BenchDB: attempt to create an object with wrong backend'

class Instance
  constructor: (@api, @id, @type, @data) ->
    apiOk @api
    if not _.isString @id
      throw 'BenchDB::Instance: attempt to create an instance without id'
    if not _.isObject @data
      @data = {}
    if not @type instanceOf Type
      throw 'BenchDB::Instance: atempt to create an instance with wrong type'
    @data._id = @id
    Object.defineProperty @data, 'type', value: @type.name

  refresh: (cb) ->
    apiOk @api
    @api.retrieve @id, (error, res) =>
      if not error
        @data = res
      cb error, res

  save: (cb) ->
    apiOk @api
    @api.existsBool @data, (error, res) =>
      if error?
        cb error, res
      else if res
        isConflicted = true
        modifyAttempt = (whilstCb) =>
          @api.modify @data, (error, res) =>
            if not error and res.error is 'conflict'
              isConflicted = true
              @api.retrieve @data, (error, res) =>
                if error?
                  whilstCb error, res
                else
                  @data = res
                  whilstCb error, res
            else
              isConflicted = false
              whilstCb error, res
        async.doWhilst modifyAttempt, (-> isConflicted), cb
      else
        @api.create @data, cb

class Type
  constructor: (@api, @name) ->
    apiOk @api

  create: (isSingleton, id, cb) ->
    apiOk @api
    if _.isFunction isSingleton
      cb = isSingleton
    else if _.isFunction id
      cb = id
    if _.isString isSingleton
      id = isSingleton
    else if not _.isString id
      id = null
    if not _.isBoolean isSingleton
      isSingleton = true

class DB
  docIdOk = (docId) -> _.isString(docId) or _.isNumber(docId)
  wrapCb = (cb) ->
    if _.isFunction cb
      (err, dummy, body) ->
        cb err, body
    else
      throw 'BenchDB: passed callback is not a function'

  constructor: (host, port, pathPrefix, dbname) ->
    @alwaysCheckExists = false
    if port? and _.isString pathPrefix
      if _.first(pathPrefix) isnt '/'
        pathPrefix = "/#{ pathPrefix }"
      if _.last(pathPrefix) isnt '/'
        pathPrefix = "#{ pathPrefix }/"
      if dbname?
        @root = "http://#{ host }:#{ port }#{ pathPrefix }#{ dbname }/"
      else
        @root = "http://#{ host }:#{ port }#{ pathPrefix }"
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
    resTest = (res) -> _.isObject(res) and res.error isnt 'not_found'
    if _.isFunction doc then @exists (error, res) -> doc error, resTest res
    else @exists doc, (error, res) -> cb error, resTest res

  checkExists: (endCb) ->
    async.waterfall [
      ((cb) => @existsBool cb),
      ((res, cb) => if res then cb 'ok' else @createItself cb),
      ((res, cb) -> if res.ok then cb 'ok' else cb res)],
      (error) -> if error is 'ok' then endCb null else endCb error

  retrieveAll: (cb) ->
    request "#{ @root }_all_docs?include_docs=true", wrapCb cb

  retrieve: (doc, cb) ->
    if _.isObject(doc) and docIdOk(doc._id)
      request "#{ @root }#{ doc._id }", wrapCb cb
    else if docIdOk doc
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

  removeItself: (cb) -> request.del @root, wrapCb cb

  remove: (doc, rev, cb) ->
    if _.isObject(doc) and docIdOk(doc._id) and _.isFunction rev
      request.del "#{ @root }#{ doc._id }?rev=#{ doc._rev }", wrapCb rev
    else if docIdOk(doc) and _.isString rev
      request.del "#{ @root }#{ doc }?rev=#{ rev }", wrapCb cb
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
