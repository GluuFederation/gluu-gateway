'use strict';

var _ = require('lodash');
var httpRequest = require('request-promise');

/**
 * ClientsController - Used to manage OP client for plugins
 *
 * @description :: Server-side logic for managing Users
 * @help        :: See http://links.sailsjs.org/docs/controllers
 */
module.exports = _.merge(_.cloneDeep(require('../base/Controller')), {
  addOAuthClient: function (req, res) {
    if (req.body.client_id && req.body.client_secret) {
      sails.models.client
        .create({
          client_id: req.body.client_id,
          client_secret: req.body.client_secret,
          context: 'OAuth'
        })
        .exec(function (err, client) {
          return res.send(client)
        })
    } else {
      const option = {
        method: 'POST',
        uri: sails.config.oxdWeb + '/register-site',
        body: {
          op_host: sails.config.opHost,
          authorization_redirect_uri: 'https://client.example.com/cb',
          client_name: 'gluu-oauth2-introspect-client',
          setup_client_name: 'gluu-oauth2-introspect-setup-client'
        },
        resolveWithFullResponse: true,
        json: true
      };

      return httpRequest(option)
        .then(function (response) {
          var clientInfo = response.body;
          sails.models.client
            .create({
              client_id: clientInfo.client_id,
              client_secret: clientInfo.client_secret,
              context: 'OAuth'
            })
            .then(function (err, client) {
              return res.send(client)
            });
        })
    }

  },

  updateOAuthClient: function (req, res) {

  }
});
