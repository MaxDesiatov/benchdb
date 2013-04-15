_ = require 'underscore'

module.exports =
  docIdOk: (docId) ->
    (_.isString(docId) and docId.length > 0) or _.isNumber(docId)