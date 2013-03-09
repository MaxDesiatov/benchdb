nodeHttp = require 'http'
urlParse = require('url').parse
walk = require 'walkdir'
_ = require 'underscore'
common = require './common'
a = require 'async'
mime = require 'mime-magic'
fs = require 'fs'

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
  options = _(options).extend urlParse url

  req = nodeHttp.request options, requestCb
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
    options.headers = common.jsonHeader

  httpProtoJson url, options, startCb, endCb

httpBodyFile = (url, method, filepath, endCb) ->
  options = method: method
  stats = {}
  filetype = ''

  a.waterfall [
    ((cb) ->
      mime filepath, (err, result) ->
        if err?
          if err.toString().indexOf 'illegal byte sequence' > 0
            cb null, 'application/octet-stream'
          else
            cb err
        else
          cb null, result),
    ((ft, cb) ->
      filetype = ft
      fs.stat filepath, cb),
    ((s, cb) ->
      stats = s
      fs.readFile filepath, cb),
    ((data, cb) ->
      startCb = (request) ->
        request.write data
      options.headers =
        'Content-Type': filetype
        'Content-Length': stats.size
      httpProtoJson url, options, startCb, cb)], endCb

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
          path.join(path.dirname relativeFilePath,
                    path.basename(relativeFilePath, '.js')).split path.sep
        reduceFun = (res, el) ->
          result = {}
          result[el] = res
          result

        fileContents = fs.readFileSync file, 'UTF-8'

        result =
          _(result).extend _.reduce(modulePath.reverse(), reduceFun, fileContents)

  result

module.exports =
  get: httpGet
  put: httpPut
  post: httpPost
  delete: httpDelete
  protoPipe: httpProtoPipe
  bodyFile: httpBodyFile
