'use strict';

var _ = require('lodash');

/**
 * AuditLog.js
 *
 * @description :: Manage OIDC plugin logs
 * @docs        :: http://sailsjs.org/#!documentation/models
 */
var defaultModel = _.merge(_.cloneDeep(require('../base/Model')), {
  tableName: "konga_auditlogs",
  autoPK: false,
  attributes: {
    id: {
      type: 'integer',
      primaryKey: true,
      unique: true,
      autoIncrement: true
    },
    comment: {
      type: 'string',
      required: true
    },
    route_id: {
      type: 'string'
    },
    data: {
      type: 'json'
    }
  },
  afterCreate: function (values, cb) {
    sails.sockets.blast('events.auditlogs', {
      verb: 'created',
      data: values
    });
    cb()
  }
});


var mongoModel = function () {
  var obj = _.cloneDeep(defaultModel);
  delete obj.autoPK;
  delete obj.attributes.id;
  return obj;
};

module.exports = sails.config.models.connection == 'mongo' ? mongoModel() : defaultModel;
