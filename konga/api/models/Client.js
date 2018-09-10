'use strict';

var _ = require('lodash');

/**
 * Client.js
 *
 * @description :: Manage OP clients
 * @docs        :: http://sailsjs.org/#!documentation/models
 */
var defaultModel = _.merge(_.cloneDeep(require('../base/Model')), {
  tableName: "konga_clients",
  autoPK: false,
  attributes: {
    id: {
      type: 'integer',
      primaryKey: true,
      unique: true,
      autoIncrement: true
    },
    oxd_id: {
      type: 'string',
      required: true
    },
    client_id: {
      type: 'string',
      required: true
    },
    client_secret: {
      type: 'string',
      required: true
    },
    context: {
      type: 'string',
      required: true
    },
    data: {
      type: 'json'
    }
  },
  afterCreate: function (values, cb) {
    sails.log("Client created!!!!!!!!!!!!!!!!!!!!!!!!!")
    sails.sockets.blast('events.clients', {
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
}

module.exports = sails.config.models.connection == 'mongo' ? mongoModel() : defaultModel;
