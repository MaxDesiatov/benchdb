http = require 'http'
urlParse = require('url').parse
path = require 'path'
fs = require 'fs'
walk = require 'walkdir'
_ = require 'underscore'
a = require 'async'

class DB
  docIdOk = (docId) -> _.isString(docId) or _.isNumber(docId)

  constructor: (host, port, dbname) ->
    if port? and dbname?
      @root = "http://#{ host }:#{ port }/#{ dbname }/"
    else if _.isString host
      @root = host
      if _.last(@root) isnt '/'
        @root = "#{ @root }/"
    else
      throw 'DB.constructor: attempt to create a DB without name and host'

    @validationDocUrl = "#{ @root }_design/validation"

  exists: (doc, cb) ->
    if _.isObject(doc) and docIdOk(doc._id)
      httpGet "#{ @root }#{ doc._id }", cb
    else if docIdOk(doc)
      httpGet "#{ @root }#{ doc }", cb
    else if _.isFunction doc
      httpGet @root, doc
    else
      throw 'DB.exists: no document id and/or callback specified'

  existsBool: (doc, cb) ->
    if _.isFunction(doc)
      @exists (error, res) -> doc(error, res.error isnt 'not_found')
    else
      @exists doc, (error, res) -> cb(error, res.error isnt 'not_found')

  checkExists: (endCb) ->
    a.waterfall [
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
    httpGet "#{ @root }_all_docs?include_docs=true", cb

  retrieve: (doc, cb) ->
    if _.isObject(doc) and docIdOk(doc._id)
      httpGet "#{ @root }#{ doc._id }", cb
    else if docIdOk(doc)
      httpGet "#{ @root }#{ doc }", cb
    else
      throw 'DB.retrieve: no document id and/or callback specified'

  createItself: (cb) ->
    httpPut @root, cb

  create: (doc, cb) ->
    if _.isObject(doc) and docIdOk(doc._id)
      httpPut "#{ @root }#{ doc._id }", doc, cb
    else if docIdOk(doc)
      httpPut "#{ @root }#{ doc }", cb
    else if _.isFunction cb
      httpPost @root, doc, cb
    else
      throw 'DB.create: no document id and/or callback specified'

  removeItself: (cb) ->
    httpDelete @root, cb

  remove: (doc, cb) ->
    if _.isObject(doc) and docIdOk(doc._id)
      httpDelete "#{ @root }#{ doc._id }", cb
    else if docIdOk(doc)
      httpDelete "#{ @root }#{ doc }", cb
    else
      throw 'DB.remove: no document id and/or callback specified'

  modify: (doc, cb) ->
    if _.isObject(doc) and docIdOk(doc._id)
      httpPut "#{ @root }#{ doc._id }", doc, cb
    else
      throw 'DB.modify: no document id and/or callback specified'

  downloadAttachment: (doc, filename, directory, cb) ->
    if docIdOk doc._id
      url = "#{ @root }#{ doc._id }/#{ filename }"
      httpProtoPipe url, path.join(filename, directory), method: 'GET', null, cb
    else
      throw 'DB.downloadAttachment: no document id specified'

  attachFile: (doc, filepath, cb) ->
    if docIdOk doc._id
      url = "#{ @root }#{ doc._id }/attachment?rev=#{ doc._rev }"
      httpBodyFile url, 'PUT', filepath, cb
    else
      throw 'DB.attachFile: no document id specified'

jsonHeader = 'Content-Type': 'application/json'

httpProtoPipe = (url, filepath, options, startCb, endCb) ->
  callback = (response) ->
    response.pipe fs.createWriteStream filepath

    if _.isFunction endCb
      response.on 'end', -> endCb null, {}

  httpProto url, options, startCb, callback

httpProtoJson = (url, options, startCb, endCb) ->
  callback = (response) ->
    result = ''
    response.on 'data', (chunk) ->
      result += chunk

    if _.isFunction endCb
      response.on 'end', ->
        res = (
          try
            JSON.parse result
          catch _
            result)
        endCb null, res

  httpProto url, options, startCb, callback

httpProto = (url, options, startCb, requestCb) ->
  options = _(options).extend(urlParse url)

  req = http.request options, requestCb
  if _.isFunction startCb
    startCb req
  req.end()

httpBodyJson = (url, method, body, endCb) ->
  options = method: method

  if _.isFunction(body) and not endCb?
    endCb = body
  else if not _.isEmpty body
    startCb = (request) ->
      request.write JSON.stringify body
    options.headers = jsonHeader

  httpProtoJson url, options, startCb, endCb

httpBodyFile = (url, method, filepath, endCb) ->
  options = method: method

  mime filepath, (error, filetype) ->
    if error?
      cb error, {}
    else
      fs.readFile filepath, (err, data) ->
        if err?
          cb err, {}
        else
          startCb = (request) ->
            request.write data
          options.headers = 'Content-Type': filetype
          httpProto url, options, startCb, endCb

httpGet = (url, cb) ->
  httpProtoJson url, method: 'GET', null, cb
httpPut = (url, body, endCb) -> httpBodyJson url, 'PUT', body, endCb
httpPost = (url, body, endCb) -> httpBodyJson url, 'POST', body, endCb
httpDelete = (url, body, endCb) -> httpBodyJson url, 'DELETE', body, endCb

readPackageJson = (moduleDir, packageName) ->
  filePath = path.join moduleDir, packageName, 'package.json'
  if fs.existsSync filePath
    JSON.parse(fs.readFileSync filePath)

stringifyModule = (moduleName, packageName) ->
  for dir in process.env.NODE_PATH.split ':'
    packageInfo = readPackageJson dir, packageName
    libPath = path.join dir, packageName
    if packageInfo.directories?
      libPath = path.join libPath, packageInfo.directories.lib
    if packageInfo? and fs.existsSync libPath
        filePath = path.join libPath, "#{ moduleName }.js"
        return fs.readFileSync filePath, 'UTF-8'

stringifyPackage = (packageName) ->
  result = {}

  for dir in process.env.NODE_PATH.split ':'
    packageInfo = readPackageJson dir
    mainPath = path.join dir, packageName, packageInfo.main
    if packageInfo? and fs.existsSync mainPath
      mainDir = path.dirname mainPath
      for file in walk.sync mainDir when path.extname(file) is '.js'
        relativeFilePath = path.relative mainDir, file
        modulePath =
          path.join(path.dirname(relativeFilePath),
                    path.basename(relativeFilePath, '.js')).split(path.sep)
        reduceFun = (res, el) ->
          result = {}
          result[el] = res
          result

        fileContents = fs.readFileSync file, 'UTF-8'

        result =
          _(result).extend _.reduce(modulePath.reverse(), reduceFun, fileContents)

  result

module.exports = DB
