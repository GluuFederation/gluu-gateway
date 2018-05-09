'use strict';

var _ = require('lodash');
var HealthCheckEvents = require("../events/node-health-checks")

/**
 * KongNode.js
 *
 * @description :: TODO: You might write a short summary of how this model works and what it represents here.
 * @docs        :: http://sailsjs.org/#!documentation/models
 */
var defaultModel = _.merge(_.cloneDeep(require('../base/Model')), {
  tableName : "konga_kong_nodes",
  autoPK : false,
  attributes: {
    id : {
      type: 'integer',
      primaryKey: true,
      unique: true,
      autoIncrement : true
    },
    name: {
      type: 'string',
      required : true
    },
    kong_admin_url: {
      type: 'string',
      required : true
    },
    kong_api_key: {
        type: 'string',
        defaultsTo : ''
    },
    kong_version: {
      type: 'string',
      required : true,
      defaultsTo : '0-11-x'
    },
    health_checks : {
      type : 'boolean',
      defaultsTo : false
    },
    health_check_details : {
      type : 'json'
    },
    active: {
      type: 'boolean',
      required : true,
      defaultsTo : false
    }
  },

  afterDestroy: function (values, cb) {

    sails.log("KongNode:afterDestroy:called => ",values);

    // Stop health checks
    values.forEach(function(node){
      HealthCheckEvents.emit('health_checks.stop',node);
    })

    cb();

  },

  afterUpdate: function (values, cb) {

    sails.log("KongNode:afterUpdate:called()")
    sails.log("KongNode:afterUpdate:health_checks",values.health_checks)

    // Manage toggle health checks
    if(values.health_checks) {
      // Send event to begin health checks for the updated node
      sails.log("KongNode:afterUpdate:emit health_checks.start")
      HealthCheckEvents.emit('health_checks.start',values);
    }else{
      // Send event to stop health checks for the updated node
      sails.log("KongNode:afterUpdate:emit health_checks.stop")
      HealthCheckEvents.emit('health_checks.stop',values);
    }

    cb()
  },
  seedData : [
    {
      "name" : "default",
      "kong_admin_url": sails.config.kong_admin_url,
      "active": true
    }
  ]
});


var mongoModel = function() {
  var obj = _.cloneDeep(defaultModel)
  delete obj.autoPK
  delete obj.attributes.id
  return obj;
}

module.exports = sails.config.models.connection == 'mongo' ? mongoModel() : defaultModel
