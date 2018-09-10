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

  // User to register client for OAuth plugin
  addOAuthClient: function (req, res) {
    // Promise for handle async process
    new Promise(function (resolve, reject) {
      // Existing client id and secret
      if (req.body.oxd_id && req.body.client_id && req.body.client_secret) {
        return resolve({oxd_id: req.body.oxd_id, client_id: req.body.client_id, client_secret: req.body.client_secret})
      }

      // Create new client
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
          var clientInfo = response.body.data;
          return resolve({oxd_id: clientInfo.oxd_id, client_id: clientInfo.client_id, client_secret: clientInfo.client_secret})
        })
        .catch(function (error) {
          return reject(error)
        });
    })
      .then(function (client) {
        return sails.models.client
          .create({
            oxd_id: client.oxd_id,
            client_id: client.client_id,
            client_secret: client.client_secret,
            context: 'OAuth'
          });
      })
      .then(function (client) {
        return res.send(client);
      })
      .catch(function (err) {
        return res.status(500).send(err);
      });
  },

  updateOAuthClient: function (req, res) {

  }
});
