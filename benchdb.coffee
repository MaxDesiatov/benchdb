weak = require 'weak'
docIdOk = require('./common').docIdOk
_ = require 'underscore'
__ = require 'arguejs'
DB = require './api'
async = require 'async'
falafel = require 'falafel'
lang = require 'cssauron-falafel'
url = require 'url'

# FIXME: should also test for WeakMap in browsers
weakOk = _.isFunction(weak) or (_.isObject(weak) and not _.isEmpty(weak))

apiOk = (api) ->
  if not api instanceof DB
    throw 'BenchDB: attempt to create an object with wrong backend'

class Instance
  attemptApiCall = (instance, apiCall, continueOnConflict, cb) ->
    isConflicted = true
    attemptCycle = (whilstCb) ->
      apiCall instance.data, (error, res) ->
        if not error and res.error is 'conflict'
          isConflicted = true
          intance.refresh whilstCb
        else
          isConflicted = false
          whilstCb error, res
    if continueOnConflict
      async.doWhilst attemptCycle, (-> isConflicted), cb
    else
      attemptCycle cb

  constructor: (api, id, @type) ->
    apiOk api
    Object.defineProperty @, 'api', value: api
    if not docIdOk id
      throw 'BenchDB::Instance: attempt to create an instance without id'
    Object.defineProperty @, 'id', value: id
    if not @type instanceof Type
      throw 'BenchDB::Instance: atempt to create an instance with wrong type'
    Object.defineProperty @, 'data',
      set: (newData) =>
        delete newData._id
        delete newData.type
        Object.defineProperty newData, '_id', { value: id, enumerable: true }
        Object.defineProperty newData, 'type',
          { value: @type.name, enumerable: true }
        @__data = newData
      get: => @__data
    @data = {}

  refresh: (cb) ->
    @api.retrieve @id, (error, res) =>
      if not error
        @data = res
      cb error, res

  save: ->
    { continueOnConflict, cb } =
      __ continueOnConflict: [Boolean, false], cb: Function
    @api.existsBool @id, (error, res) =>
      if error?
        cb error, res
      else if res
        attemptApiCall @, _(@api.modify).bind(@api), continueOnConflict, cb
      else
        @api.create @data, cb

  remove: ->
    { continueOnConflict, cb } =
      __ continueOnConflict: [Boolean, false], cb: Function
    if @data._rev
      attemptApiCall @, _(@api.remove).bind(@api), continueOnConflict, cb
    else
      cb "attempt to remove a document when it doesn't have a revision", null

class Type
  filterSource = (doc) ->
    filterObject = {}
    result = true

    lastField = '_id'
    for filterField, filterValue of filterObject
      if (filterValue is null and doc[filterField] is undefined) or
      (filterValue isnt null and doc[filterField] isnt filterValue)
        result = false
        break
      lastField = filterField

    if result
      emit doc[lastField]

  constructor: (api, name) ->
    if not _.isString(name) or name.length < 1
      throw 'BenchDB::Type: atempt to create a type without a name'
    Object.defineProperty @, 'name', value: name
    apiOk api
    Object.defineProperty @, 'api', value: api
    if not weakOk
      Object.defineProperty @, 'cache', value: {}
    else
      @cache = {}

  instance: ->
    { isSingleton, id, cb } = __
      isSingleton: Boolean, id: [String], cb: Function
    cacheAndCallback = =>
      if isSingleton and weakOk
        strong = @cache[id] and weak.get(@cache[id])
        if not _.isEmpty(strong) and strong instanceof Instance
          cb null, strong
        else
          strong = new Instance @api, id, @
          @cache[id] = weak strong
          cb null, strong
      else
        cb null, (new Instance @api, id, @)
    if id?
      cacheAndCallback()
    else
      @api.uuids (err, res) ->
        if err?
          cb err, res
        else if _.isArray res
          id = res[0]
          cacheAndCallback()
        else
          throw 'BenchDB::Type.instance: inconsistent behavior of @api.uuids'

  all: (cb) -> @filterByField cb

  filterByField: ->
    { viewOpts, field, value, cb } =
      __
        viewOpts: [Object, {}]
        field: [String]
        value: [undefined, null]
        cb: Function
    filterObject = type: @name
    if field?
      filterObject[field] = null
    # for some reason esprima doesn't parse stray function expressions
    # so transforming filterSource to variable assignment...
    mapSource = (falafel ('var f = ' + filterSource + ''), (node) ->
      if lang('assign')(node) and node.left.name is 'filterObject'
        node.update "filterObject = #{ JSON.stringify filterObject }"
      # ...and then back to function expression
      else if lang('variable-decl')(node) and
      node.declarations[0].id.name is 'f'
        node.update node.declarations[0].init.source()).toString()

    docId = "_design/_benchdb"
    viewName = "#{@name}_#{if field then field else ''}"

    instantiateRows = (rows) =>
      iterator = (id, next) => @instance true, id, next
      async.map (row.id for row in rows), iterator, (err, results) ->
        cb err, results

    getViewResults = =>
      stringifiedFields = ['key', 'keys', 'startkey', 'endkey']
      for field, value of viewOpts when field in stringifiedFields
        viewOpts[field] = JSON.stringify value
      query = url.format query: viewOpts
      @api.retrieve "#{docId}/_view/#{viewName}#{query}", (err, res) =>
        if err?
          cb err, res
        else if _.isArray res.rows
          # workaround for CouchDB not returning rows when more than one exact
          # match is found
          if res.total_rows > 0 and res.rows.length is 0
            if viewOpts.key and not viewOpts.startkey and not viewOpts.endkey
              delete viewOpts.key
              viewOpts.startkey = value
              viewOpts.endkey = value
              getViewResults()
          else
            instantiateRows res.rows
        else
          cb 'malformed view results', res

    @api.retrieve docId, (err, res) =>
      if err?
        cb err, res
        return
      if res.error is 'not_found'
        res = _id: docId, language: 'javascript', views: {}
        res.views[viewName] = {}

      if value?
        viewOpts.key = value

      if not _.isObject(res.views[viewName]) or
      res.views[viewName].map isnt mapSource or res.views[viewName].reduce?
        res.views[viewName] = map: mapSource
        @api.modify res, (err, errRes) ->
          if err?
            cb err, errRes
          else
            getViewResults()
      else
        getViewResults()

module.exports = Type
