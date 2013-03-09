class DB
  docIdOk = (docId) -> _.isString(docId) or _.isNumber(docId)
  path = null
  _ = null
  async = null
  http = null

  setupEnv = (env) ->
    path = env and env.path or require 'path'
    _ = env and env._ or require 'underscore'
    async = env and env.async or require 'async'
    http = env and env.http or require './node'

  constructor: (host, port, dbname, env) ->
    @alwaysCheckExists = false
    if port? and dbname?
      setupEnv env
      @root = "http://#{ host }:#{ port }/#{ dbname }/"
    else
      setupEnv port
      if _ and _.isString host
        @root = host
        if _.last(@root) isnt '/'
          @root = "#{ @root }/"
      else
        throw 'BenchDB.constructor: attempt to create a DB without name and host'

    @validationDocUrl = "#{ @root }_design/validation"

  exists: (doc, cb) ->
    if _.isObject(doc) and docIdOk(doc._id)
      http.get "#{ @root }#{ doc._id }", cb
    else if docIdOk(doc)
      http.get "#{ @root }#{ doc }", cb
    else if _.isFunction doc
      http.get @root, doc
    else
      throw 'BenchDB.exists: no document id and/or callback specified'

  existsBool: (doc, cb) ->
    if _.isFunction(doc)
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
    http.get "#{ @root }_all_docs?include_docs=true", cb

  retrieve: (doc, cb) ->
    if _.isObject(doc) and docIdOk(doc._id)
      http.get "#{ @root }#{ doc._id }", cb
    else if docIdOk(doc)
      http.get "#{ @root }#{ doc }", cb
    else
      throw 'BenchDB.retrieve: no document id and/or callback specified'

  createItself: (cb) ->
    http.put @root, cb

  create: (doc, cb) ->
    if _.isObject(doc) and docIdOk(doc._id)
      http.put "#{ @root }#{ doc._id }", doc, cb
    else if docIdOk(doc)
      http.put "#{ @root }#{ doc }", cb
    else if _.isFunction cb
      http.post @root, doc, cb
    else
      throw 'BenchDB.create: no document id and/or callback specified'

  removeItself: (cb) ->
    http.delete @root, cb

  remove: (doc, cb) ->
    if _.isObject(doc) and docIdOk(doc._id)
      http.delete "#{ @root }#{ doc._id }", cb
    else if docIdOk(doc)
      http.delete "#{ @root }#{ doc }", cb
    else
      throw 'BenchDB.remove: no document id and/or callback specified'

  modify: (doc, cb) ->
    if _.isObject(doc) and docIdOk(doc._id)
      http.put "#{ @root }#{ doc._id }", doc, cb
    else
      throw 'BenchDB.modify: no document id and/or callback specified'

  downloadAttachment: (doc, filename, directory, cb) ->
    if docIdOk doc._id
      url = "#{ @root }#{ doc._id }/#{ filename }"
      http.protoPipe url, path.join(directory, filename), method: 'GET', null, cb
    else
      throw 'BenchDB.downloadAttachment: no document id specified'

  uploadAttachment: (doc, filepath, filename, cb) ->
    if docIdOk doc._id
      url = "#{ @root }#{ doc._id }/#{ filename }?rev=#{ doc._rev }"
      http.bodyFile url, 'PUT', filepath, cb
    else
      throw 'BenchDB.attachFile: no document id specified'

module.exports = DB
